-- ---------------------------------------------------------------------------
-- 舊照片改用 Storage API 刪除（全景地圖 4-O，2026-10-31）
--
-- 問題：Supabase 在 storage.objects 加了保護觸發器 protect_objects_delete，
--       不准用 SQL 直接刪照片紀錄（只刪紀錄、實體檔案會變成沒人管的檔案）。
--       下面三個舊觸發器用 SQL 直接刪照片，會被擋下，連帶讓整個動作失敗：
--         - 換掉／清除已有的大頭照
--         - 換掉／清除已有的客戶照片
--         - 永久刪除有照片的客戶（垃圾桶、刪除帳號的連帶刪除）
-- 做法：移除這三個觸發器與函式；舊照片改由 App 與 delete-account 函式用 Storage API 刪除。
-- 不新增資料表、不改 RLS；Storage 既有政策已允許使用者刪除自己資料夾的檔案。
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trigger_delete_customer_photo ON public.customers;
DROP TRIGGER IF EXISTS trigger_delete_old_customer_photo ON public.customers;
DROP TRIGGER IF EXISTS trigger_delete_old_avatar ON public.profiles;

DROP FUNCTION IF EXISTS public.delete_customer_photo_on_delete();
DROP FUNCTION IF EXISTS public.delete_old_customer_photo_on_update();
DROP FUNCTION IF EXISTS public.delete_old_avatar_on_update();
