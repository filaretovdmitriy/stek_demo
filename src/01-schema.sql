create table физические_лица (
    id int8 primary key,
    фио text not null,
    адрес text not null
);

create table юридические_лица (
    id int8 primary key,
    наименование text not null,
    инн text not null
);

create table платежи (
    id int8 primary key,
    физическое_лицо int8 references физические_лица(id),
    юридическое_лицо int8 references юридические_лица(id),
    сумма int4 not null,
    дата date not null,
    constraint платежи_один_плательщик_check check (
        num_nonnulls(физическое_лицо, юридическое_лицо) = 1
    )
);

insert into физические_лица (id, фио, адрес)
values
    (1, 'Иванов Иван Иванович', 'ул. Малая Химическая, 7а'),
    (2, 'Петров Петр Петрович', 'ул. Малая Химическая, 7б');

insert into юридические_лица (id, наименование, инн)
values
    (1, 'ООО Вектор', '520278984556'),
    (2, 'ЗАО Развитие', '910318984495');

insert into платежи (
    id,
    физическое_лицо,
    юридическое_лицо,
    сумма,
    дата
)
values
    (85, 1, null, 215, '2021-05-14'),
    (78, 1, null, 207, '2021-06-20'),
    (59, 2, null, 318, '2021-07-03'),
    (13, 2, null, 345, '2021-08-05'),
    (11, null, 1, 17025, '2021-07-09'),
    (96, null, 1, 19162, '2021-08-16'),
    (61, null, 2, 8944, '2021-06-18'),
    (45, null, 2, 7852, '2021-07-25'),
    (37, null, 2, 4559, '2021-07-29'),
    (55, null, 2, 9367, '2021-09-06');

create or replace function абоненты_с_задолженностью(
    начало_периода date,
    количество_месяцев int4
)
returns table (
    абонент text,
    месяцев_оплачено int4,
    дата_последнего_платежа date,
    сумма_последнего_платежа int4
)
language sql
stable
as $$
    select
        результат.абонент,
        результат.месяцев_оплачено,
        результат.дата_последнего_платежа,
        результат.сумма_последнего_платежа
    from (
        select
            фл.фио as абонент,
            статистика.месяцев_оплачено,
            статистика.дата_последнего_платежа,
            последний.сумма as сумма_последнего_платежа
        from физические_лица фл
        cross join lateral (
            select
                count(
                    distinct date_trunc('month', п.дата)
                )::int4 as месяцев_оплачено,
                max(п.дата) as дата_последнего_платежа
            from платежи п
            where п.физическое_лицо = фл.id
              and п.дата >= $1
              and п.дата <
                  ($1 + make_interval(months => $2))::date
        ) статистика
        left join lateral (
            select п.сумма
            from платежи п
            where п.физическое_лицо = фл.id
              and п.дата >= $1
              and п.дата <
                  ($1 + make_interval(months => $2))::date
            order by п.дата desc
            limit 1
        ) последний on true
        where статистика.месяцев_оплачено < $2

        union all

        select
            юл.наименование as абонент,
            статистика.месяцев_оплачено,
            статистика.дата_последнего_платежа,
            последний.сумма as сумма_последнего_платежа
        from юридические_лица юл
        cross join lateral (
            select
                count(
                    distinct date_trunc('month', п.дата)
                )::int4 as месяцев_оплачено,
                max(п.дата) as дата_последнего_платежа
            from платежи п
            where п.юридическое_лицо = юл.id
              and п.дата >= $1
              and п.дата <
                  ($1 + make_interval(months => $2))::date
        ) статистика
        left join lateral (
            select п.сумма
            from платежи п
            where п.юридическое_лицо = юл.id
              and п.дата >= $1
              and п.дата <
                  ($1 + make_interval(months => $2))::date
            order by п.дата desc
            limit 1
        ) последний on true
        where статистика.месяцев_оплачено < $2
    ) результат
    order by результат.абонент;
$$;
