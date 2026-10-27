-- 實支實付理賠限額匯入檔（D14）：由 tool/benefit_plans/build_seed_sql.py 產生，請勿手改
-- 在 Supabase SQL Editor 執行；可重複執行。最後會列出每款商品匯入了幾個計畫（對不到的商品是 0）。
INSERT INTO public.insurance_product_benefit_plans (product_id, plan_code, plan_order, benefit_type, room_daily_limit, hospital_expense_limit, surgery_limit, outpatient_surgery_limit, per_admission_total_limit, annual_total_limit, lifetime_total_limit, room_deductible, hospital_expense_deductible, outpatient_surgery_deductible, daily_hospital_benefit, hospital_expense_includes_surgery, note, source_page)
SELECT p.id, v.plan_code::text, v.plan_order::integer, v.benefit_type::text, v.room_daily_limit::integer, v.hospital_expense_limit::integer, v.surgery_limit::integer, v.outpatient_surgery_limit::integer, v.per_admission_total_limit::integer, v.annual_total_limit::integer, v.lifetime_total_limit::integer, v.room_deductible::integer, v.hospital_expense_deductible::integer, v.outpatient_surgery_deductible::integer, v.daily_hospital_benefit::integer, v.hospital_expense_includes_surgery::boolean, v.note::text, v.source_page::integer
FROM (VALUES
  ('cathay', '國泰人壽新iHealth一年期住院醫療健康保險（外溢型）', '7萬', 1, 'itemized', 1000, 70000, NULL, 15000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 8),
  ('cathay', '國泰人壽新iHealth一年期住院醫療健康保險（外溢型）', '14萬', 2, 'itemized', 2000, 140000, NULL, 20000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 8),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（A型）', '10萬', 1, 'itemized', 1000, 100000, NULL, 20000, NULL, NULL, NULL, NULL, NULL, NULL, 1000, true, NULL, 10),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（A型）', '20萬', 2, 'itemized', 2000, 200000, NULL, 30000, NULL, NULL, NULL, NULL, NULL, NULL, 2000, true, NULL, 10),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（A型）', '30萬', 3, 'itemized', 3000, 300000, NULL, 40000, NULL, NULL, NULL, NULL, NULL, NULL, 3000, true, NULL, 10),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（B型）', '10萬', 1, 'itemized', 1000, 100000, NULL, 20000, NULL, NULL, NULL, NULL, NULL, NULL, 1000, true, NULL, 11),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（B型）', '20萬', 2, 'itemized', 2000, 200000, NULL, 30000, NULL, NULL, NULL, NULL, NULL, NULL, 2000, true, NULL, 11),
  ('cathay', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（B型）', '30萬', 3, 'itemized', 3000, 300000, NULL, 40000, NULL, NULL, NULL, NULL, NULL, NULL, 3000, true, NULL, 11),
  ('cathay', '國泰人壽點實成金住院醫療終身保險（外溢型）', '10萬', 1, 'itemized', 1000, 100000, NULL, 30000, NULL, NULL, NULL, NULL, NULL, NULL, 1000, true, '住院時實支或日額擇優給付', 13),
  ('cathay', '國泰人壽點實成金住院醫療終身保險（外溢型）', '20萬', 2, 'itemized', 2000, 200000, NULL, 40000, NULL, NULL, NULL, NULL, NULL, NULL, 2000, true, '住院時實支或日額擇優給付', 13),
  ('cathay', '國泰人壽點實成金住院醫療終身保險（外溢型）', '30萬', 3, 'itemized', 3000, 300000, NULL, 50000, NULL, NULL, NULL, NULL, NULL, NULL, 3000, true, '住院時實支或日額擇優給付', 13),
  ('cathay', '國泰人壽新實全心意PLUS住院醫療健康保險附約（外溢型）', 'M10', 1, 'deductible', 1000, 100000, NULL, 15000, NULL, 500000, NULL, NULL, NULL, 1000, 1000, true, NULL, 8),
  ('cathay', '國泰人壽新實全心意PLUS住院醫療健康保險附約（外溢型）', 'M20', 2, 'deductible', 2000, 200000, NULL, 20000, NULL, 750000, NULL, NULL, NULL, 1000, 2000, true, NULL, 8),
  ('cathay', '國泰人壽新實全心意PLUS住院醫療健康保險附約（外溢型）', 'M30', 3, 'deductible', 3000, 300000, NULL, 25000, NULL, 1000000, NULL, NULL, NULL, 1000, 3000, true, NULL, 8),
  ('cathay', '國泰人壽超實在自負額住院醫療健康保險附約（外溢型）', '計劃別1', 1, 'deductible', 1000, 100000, NULL, 10000, NULL, NULL, NULL, 1000, 100000, 10000, NULL, true, NULL, 7),
  ('cathay', '國泰人壽超實在自負額住院醫療健康保險附約（外溢型）', '計劃別2', 2, 'deductible', 2000, 200000, NULL, 20000, NULL, NULL, NULL, 1000, 100000, 10000, NULL, true, NULL, 7),
  ('cathay', '國泰人壽超實在自負額住院醫療健康保險附約（外溢型）', '計劃別3', 3, 'deductible', 1000, 100000, NULL, 20000, NULL, NULL, NULL, 2000, 200000, 10000, NULL, true, NULL, 7),
  ('fubon', '富邦人壽佳實在一年期住院醫療健康保險附約', '計劃1', 1, 'itemized', 1000, 100000, 40000, 15000, 150000, 750000, NULL, NULL, NULL, NULL, 1000, false, NULL, 8),
  ('fubon', '富邦人壽佳實在一年期住院醫療健康保險附約', '計劃2', 2, 'itemized', 2000, 200000, 60000, 20000, 300000, 1000000, NULL, NULL, NULL, NULL, 2000, false, NULL, 8),
  ('fubon', '富邦人壽佳實在一年期住院醫療健康保險附約', '計劃3', 3, 'itemized', 3000, 300000, 80000, 25000, 450000, 1500000, NULL, NULL, NULL, NULL, 3000, false, NULL, 8),
  ('fubon', '富邦人壽全鑫一年期住院醫療健康保險附約', '計劃1', 1, 'deductible', 3000, 300000, NULL, 25000, NULL, 750000, NULL, 1000, 100000, 15000, NULL, true, NULL, 8),
  ('fubon', '富邦人壽全鑫一年期住院醫療健康保險附約', '計劃2', 2, 'deductible', 3000, 300000, NULL, 25000, NULL, 500000, NULL, 2000, 200000, 20000, NULL, true, NULL, 8),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'A型', 1, 'deductible', 3000, 200000, NULL, 40000, NULL, NULL, NULL, 500, 25000, 25000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'B型', 2, 'deductible', 3000, 200000, NULL, 65000, NULL, NULL, NULL, 1000, 50000, 50000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'C型', 3, 'deductible', 3000, 200000, NULL, 90000, NULL, NULL, NULL, 1500, 75000, 75000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'D型', 4, 'deductible', 3000, 200000, NULL, 115000, NULL, NULL, NULL, 2000, 100000, 100000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'E型', 5, 'deductible', 3000, 200000, NULL, 30000, NULL, NULL, NULL, 1000, 100000, 15000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽超實踐幸福自負額住院醫療健康保險附約', 'F型', 6, 'deductible', 3000, 200000, NULL, 30000, NULL, NULL, NULL, 2000, 150000, 15000, NULL, true, NULL, 12),
  ('nanshan', '南山人壽實健溢百住院醫療終身保險', '計劃10', 1, 'itemized', 1000, 100000, NULL, 20000, NULL, NULL, 2500000, NULL, NULL, NULL, NULL, true, '實支實付前為定額給付；以下為實支實付後的限額', 17),
  ('nanshan', '南山人壽實健溢百住院醫療終身保險', '計劃20', 2, 'itemized', 2000, 200000, NULL, 40000, NULL, NULL, 5000000, NULL, NULL, NULL, NULL, true, '實支實付前為定額給付；以下為實支實付後的限額', 17),
  ('nanshan', '南山人壽實健溢百住院醫療終身保險', '計劃30', 3, 'itemized', 3000, 300000, NULL, 60000, NULL, NULL, 7500000, NULL, NULL, NULL, NULL, true, '實支實付前為定額給付；以下為實支實付後的限額', 17),
  ('fubon', '富邦人壽實在滿溢住院醫療終身健康保險', '計劃1', 1, 'itemized', 1000, 100000, NULL, 20000, NULL, NULL, 2500000, NULL, NULL, NULL, 1000, true, '實支實付保險金啟動日前為定額給付；以下為啟動日起的實支實付限額', 12),
  ('fubon', '富邦人壽實在滿溢住院醫療終身健康保險', '計劃2', 2, 'itemized', 2000, 200000, NULL, 30000, NULL, NULL, 5000000, NULL, NULL, NULL, 2000, true, '實支實付保險金啟動日前為定額給付；以下為啟動日起的實支實付限額', 12),
  ('fubon', '富邦人壽實在滿溢住院醫療終身健康保險', '計劃3', 3, 'itemized', 3000, 300000, NULL, 40000, NULL, NULL, 7500000, NULL, NULL, NULL, 3000, true, '實支實付保險金啟動日前為定額給付；以下為啟動日起的實支實付限額', 12),
  ('nanshan', '南山人壽實踐幸福住院醫療健康保險附約', 'A型', 1, 'itemized', 3000, 200000, NULL, 30000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 5),
  ('nanshan', '南山人壽實踐幸福住院醫療健康保險附約', 'B型', 2, 'itemized', 2000, 150000, NULL, 15000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 5),
  ('nanshan', '南山人壽實踐幸福住院醫療健康保險附約', 'C型', 3, 'itemized', 1000, 100000, NULL, 15000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 5),
  ('nanshan', '南山人壽實現幸福部分負擔住院醫療健康保險附約', '各型別', 1, 'itemized', 3000, 300000, NULL, 30000, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, '限額再乘以給付比例：I 型 80%、II 型 70%、III 型 60%（客戶自行負擔 20%～40%）', 5),
  ('fubon', '富邦人壽鑫安實在住院醫療終身健康保險', '依投保單位', 1, 'total', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, false, '不分項目，醫療費用都從累計總限額扣；每單位總限額為標準體躉繳保險費的一定比例（第 1 保單年度 90%，之後逐年提高），金額依投保年齡而不同', 2)
) AS v(company_code, product_name, plan_code, plan_order, benefit_type, room_daily_limit, hospital_expense_limit, surgery_limit, outpatient_surgery_limit, per_admission_total_limit, annual_total_limit, lifetime_total_limit, room_deductible, hospital_expense_deductible, outpatient_surgery_deductible, daily_hospital_benefit, hospital_expense_includes_surgery, note, source_page)
JOIN public.insurance_products p ON p.company_code = v.company_code AND p.product_name = v.product_name
ON CONFLICT (product_id, plan_code) DO UPDATE SET
  plan_order = EXCLUDED.plan_order,
  benefit_type = EXCLUDED.benefit_type,
  room_daily_limit = EXCLUDED.room_daily_limit,
  hospital_expense_limit = EXCLUDED.hospital_expense_limit,
  surgery_limit = EXCLUDED.surgery_limit,
  outpatient_surgery_limit = EXCLUDED.outpatient_surgery_limit,
  per_admission_total_limit = EXCLUDED.per_admission_total_limit,
  annual_total_limit = EXCLUDED.annual_total_limit,
  lifetime_total_limit = EXCLUDED.lifetime_total_limit,
  room_deductible = EXCLUDED.room_deductible,
  hospital_expense_deductible = EXCLUDED.hospital_expense_deductible,
  outpatient_surgery_deductible = EXCLUDED.outpatient_surgery_deductible,
  daily_hospital_benefit = EXCLUDED.daily_hospital_benefit,
  hospital_expense_includes_surgery = EXCLUDED.hospital_expense_includes_surgery,
  note = EXCLUDED.note,
  source_page = EXCLUDED.source_page,
  updated_at = now();

SELECT p.company_name, p.product_name, count(b.id) AS plan_count
FROM public.insurance_products p
LEFT JOIN public.insurance_product_benefit_plans b ON b.product_id = p.id
WHERE p.product_name IN ('國泰人壽新iHealth一年期住院醫療健康保險（外溢型）', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（A型）', '國泰人壽倍愛醫靠住院醫療定期保險（外溢型）（B型）', '國泰人壽點實成金住院醫療終身保險（外溢型）', '國泰人壽新實全心意PLUS住院醫療健康保險附約（外溢型）', '國泰人壽超實在自負額住院醫療健康保險附約（外溢型）', '富邦人壽佳實在一年期住院醫療健康保險附約', '富邦人壽全鑫一年期住院醫療健康保險附約', '南山人壽超實踐幸福自負額住院醫療健康保險附約', '南山人壽實健溢百住院醫療終身保險', '富邦人壽實在滿溢住院醫療終身健康保險', '南山人壽實踐幸福住院醫療健康保險附約', '南山人壽實現幸福部分負擔住院醫療健康保險附約', '富邦人壽鑫安實在住院醫療終身健康保險')
GROUP BY p.company_name, p.product_name
ORDER BY p.company_name, p.product_name;
