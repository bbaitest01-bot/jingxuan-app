-- ============================================================================
-- 3-E：標籤改存帳號下（問題 G2、G3、S13）
-- 日期：2026-10-13
--
-- 原因：大分類讀全公司共用的 tag_categories（會看到別人建的分類，業務員也寫不進去），
--       子標籤只存在瀏覽器本機（換裝置就不見）。
-- 做法：新建兩張「每位業務員自己的」資料表；舊的 tag_categories、tags、customer_tags
--       保留不動、App 不再使用。客戶身上的標籤仍存在 customers.tags（標籤名稱），不變。
-- 權限：RLS 只允許讀寫自己的資料（profile_id = 自己）。
-- 可重複執行：表、索引、限制都先判斷是否存在。
-- ============================================================================

-- 1. 大分類（例：客戶身分、已購險種）
CREATE TABLE IF NOT EXISTS public.user_tag_categories (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  UUID        NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  color_hex   TEXT,
  sort_order  INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_tag_categories_name_length CHECK (char_length(name) BETWEEN 1 AND 30),
  CONSTRAINT user_tag_categories_color_format CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT user_tag_categories_unique_name UNIQUE (profile_id, name),
  -- 給子標籤的「同一人」外鍵使用
  CONSTRAINT user_tag_categories_id_profile UNIQUE (id, profile_id)
);

COMMENT ON TABLE public.user_tag_categories IS '每位業務員自己的標籤大分類（3-E，取代全公司共用的 tag_categories）';

-- 2. 子標籤（例：高資產、醫療險）
CREATE TABLE IF NOT EXISTS public.user_tags (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID        NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id  UUID        NOT NULL,
  name         TEXT        NOT NULL,
  color_hex    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_tags_name_length CHECK (char_length(name) BETWEEN 1 AND 30),
  CONSTRAINT user_tags_color_format CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT user_tags_unique_name UNIQUE (profile_id, name),
  -- 子標籤只能掛在「自己的」大分類下；刪除大分類時底下的子標籤一起刪除
  CONSTRAINT user_tags_category_same_owner FOREIGN KEY (category_id, profile_id)
    REFERENCES public.user_tag_categories (id, profile_id) ON DELETE CASCADE
);

COMMENT ON TABLE public.user_tags IS '每位業務員自己的子標籤（3-E，取代只存在瀏覽器本機的子標籤）';

-- 外鍵欄位加索引（查某分類底下的標籤、刪除分類時連帶刪除都會用到）
CREATE INDEX IF NOT EXISTS idx_user_tags_category_id ON public.user_tags (category_id);

-- 3. RLS：只能讀寫自己的
ALTER TABLE public.user_tag_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Own tag categories" ON public.user_tag_categories;
CREATE POLICY "Own tag categories"
  ON public.user_tag_categories FOR ALL
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Own tags" ON public.user_tags;
CREATE POLICY "Own tags"
  ON public.user_tags FOR ALL
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (profile_id = (SELECT auth.uid()));
