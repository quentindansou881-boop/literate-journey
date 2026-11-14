-- Variante 11 : Рассрочка платежей по картам
-- Гранулярность : 1 строка = 1 платёж картой (order_id + payment_sequential)
-- Проверено на данных Olist: stg_order_payments (платежи) и core_order (order_id, purchase_ts, customer_state).
-- Если в вашем ноутбуке имена таблиц/колонок другие — замените их.

DROP VIEW IF EXISTS dm_v11_card_installments;

CREATE VIEW dm_v11_card_installments AS
SELECT
    p.order_id                                            AS order_id,
    p.payment_sequential                                  AS payment_sequential,
    p.order_id || '-' || p.payment_sequential             AS payment_key,
    p.payment_type                                        AS payment_type,
    p.payment_installments                                AS payment_installments,
    CASE WHEN p.payment_installments > 1 THEN 1 ELSE 0 END AS is_installment,
    CASE
        WHEN p.payment_installments <= 1  THEN '1 (без рассрочки)'
        WHEN p.payment_installments <= 3  THEN '2-3'
        WHEN p.payment_installments <= 6  THEN '4-6'
        WHEN p.payment_installments <= 10 THEN '7-10'
        ELSE '11+'
    END                                                   AS installment_bucket,
    p.payment_value                                       AS payment_value,
    ROUND(p.payment_value * 1.0 / NULLIF(p.payment_installments, 0), 2)
                                                          AS monthly_payment,
    substr(o.purchase_ts, 1, 7)                           AS purchase_month,
    o.customer_state                                      AS customer_state
FROM stg_order_payments p
JOIN core_order o ON o.order_id = p.order_id
WHERE p.payment_type = 'credit_card'
  AND p.payment_installments >= 1      -- в Olist есть записи с 0 платежей: аномалия, исключаем
  AND p.payment_value IS NOT NULL;
