-- ============================================================================
-- 4-A：拜訪紀錄資料表（問題 R6，第 4 階段 4-1）
-- 日期：2026-10-14
--
-- 用途：業務員錄音或打字建立的拜訪紀錄。保留「原始轉錄」，另存「整理後內容」
--       （之後由 n8n 整理或手動編輯）。設計見全景地圖 4-F。
-- 舊表 visit_logs 保留不動、不使用（欄位是拜訪結果分類，用途不同）。
-- 權限：只能讀寫自己的紀錄；連結客戶只能連自己的客戶；主管／開發者也看不到別人的
--       （內容可能有客戶病史等敏感資料，2026-10-14 沛沛確認）。
--       n8n 寫回（4-E）使用伺服器金鑰，不受 RLS 限制。
-- 可重複執行：表、索引用 IF NOT EXISTS；政策先 DROP IF EXISTS 再建立。
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.visit_records (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id             UUID        NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_id            UUID        REFERENCES public.customers(id) ON DELETE SET NULL,
  title                  TEXT        NOT NULL,
  raw_transcript         TEXT        NOT NULL DEFAULT '',
  organized_content      TEXT,
  status                 TEXT        NOT NULL DEFAULT 'raw',
  failure_reason         TEXT,
  processing_started_at  TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at             TIMESTAMPTZ,
  CONSTRAINT visit_records_title_length CHECK (char_length(title) BETWEEN 1 AND 100),
  CONSTRAINT visit_records_raw_length CHECK (char_length(raw_transcript) <= 20000),
  CONSTRAINT visit_records_organized_length CHECK (organized_content IS NULL OR char_length(organized_content) <= 20000),
  -- raw 尚未整理／processing 整理中／done 完成／failed 失敗
  CONSTRAINT visit_records_status_check CHECK (status IN ('raw', 'processing', 'done', 'failed')),
  CONSTRAINT visit_records_failure_length CHECK (failure_reason IS NULL OR char_length(failure_reason) <= 500)
);

COMMENT ON TABLE public.visit_records IS '拜訪紀錄（4-A）：原始轉錄＋整理後內容，只有本人可讀寫';
COMMENT ON COLUMN public.visit_records.raw_transcript IS '原始轉錄，一律保留（R7）';
COMMENT ON COLUMN public.visit_records.status IS 'raw 尚未整理／processing 整理中／done 完成／failed 失敗';
COMMENT ON COLUMN public.visit_records.deleted_at IS '放進垃圾桶的時間（4-D 使用）';

-- 列表（自己的、未刪除、新到舊）與客戶頁的拜訪紀錄區塊
CREATE INDEX IF NOT EXISTS idx_visit_records_list
  ON public.visit_records (profile_id, created_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_visit_records_customer_id
  ON public.visit_records (customer_id);

-- 修改時自動更新 updated_at（沿用既有的 handle_updated_at，內容相同）
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc'::text, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_visit_records_timestamp ON public.visit_records;
CREATE TRIGGER trigger_update_visit_records_timestamp
  BEFORE UPDATE ON public.visit_records
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS：只能讀寫自己的；連結的客戶必須是自己的客戶（或不連結）
ALTER TABLE public.visit_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Own visit records select" ON public.visit_records;
CREATE POLICY "Own visit records select"
  ON public.visit_records FOR SELECT
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Own visit records insert" ON public.visit_records;
CREATE POLICY "Own visit records insert"
  ON public.visit_records FOR INSERT
  TO authenticated
  WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND (
      customer_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.customers c
        WHERE c.id = customer_id AND c.profile_id = (SELECT auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS "Own visit records update" ON public.visit_records;
CREATE POLICY "Own visit records update"
  ON public.visit_records FOR UPDATE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND (
      customer_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.customers c
        WHERE c.id = customer_id AND c.profile_id = (SELECT auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS "Own visit records delete" ON public.visit_records;
CREATE POLICY "Own visit records delete"
  ON public.visit_records FOR DELETE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));
