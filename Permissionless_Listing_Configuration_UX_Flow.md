# Permissionless Listing Configuration UX Flow

## 1. 目標

定義「用戶先填入關鍵參數，系統查詢接口，再依返回結果引導後續填寫」的配置流程，確保：
- 用戶不會先填錯一大段才被拒絕
- 前後端對齊同一套 gate 規則
- 可區分 `可繼續`、`可繼續但警示`、`不可繼續`

---

## 2. 互動模式（核心）

- 單一入口參數：`symbol`
- 首次查詢：用戶輸入 `symbol` 後，點擊 `Check`
- 系統回傳：可配置欄位、建議值、限制值、風險提示、是否可進下一步
- 用戶只填「Broker 可配」欄位；不可配欄位僅展示

---

## 3. 頁面流程（Wizard）

| Step | 用戶操作 | 前端行為 | 後端接口 | 可否下一步 |
|------|----------|----------|----------|------------|
| 1. Basic Check | 輸入 `symbol`、選 `時間 T` | 送出預檢查並載入配置上下文 | `POST /listing/config/context` | `decision != BLOCK` 才可 |
| 2. Param Fill | 填寫 Broker 可配欄位（如 `quote_tick`, `base_min`, `IMR`, `Max Notional(User)`） | 每次欄位變更做即時校驗 | `POST /listing/config/validate` | 所有 required 欄位 valid 才可 |
| 3. Account Check | 選擇 IF/Liq/MM/Fee account | 檢查 account 綁定、餘額是否達標 | `POST /listing/config/account-check` | 全部 pass 才可 |
| 4. Review | 檢查摘要、警示確認 | 顯示最終參數 diff 與警示 | - | 勾選確認後可提交 |
| 5. Submit | 點擊提交 | 建立 NEW，觸發 pre-check | `POST /listing/submit` | 成功後進 NEW/PENDING |

---

## 4. API 回傳與 UX 分支

### 4.1 Context API（首次查詢）

Request:
```json
{
  "symbol": "XYZ",
  "listing_time": "2026-02-07T16:00:00Z"
}
```

Response:
```json
{
  "decision": "ALLOW_WITH_WARNINGS",
  "reasons": ["single_price_source"],
  "warnings": ["price source = 1, leverage/notional will be tightened"],
  "editable_fields": ["quote_tick", "base_min", "base_tick", "imr", "max_notional_user"],
  "locked_fields": ["min_notional", "mmr", "funding_period"],
  "defaults": {
    "min_notional": 10,
    "price_scope": 0.6
  },
  "constraints": {
    "quote_tick.max_decimals": 4,
    "imr.min": 0.1,
    "imr.max": 0.2
  }
}
```

Decision 對應前端行為：
- `ALLOW`: 直接進入 Step 2
- `ALLOW_WITH_WARNINGS`: 顯示黃條警示，允許繼續
- `BLOCK`: 顯示紅色阻斷原因，不可進下一步

### 4.2 Validate API（逐欄位）

觸發時機：
- 欄位 blur
- 點擊 Next 前整體驗證一次

Response:
```json
{
  "field": "quote_tick",
  "valid": false,
  "code": "DECIMAL_EXCEED",
  "message": "quote_tick decimals must be <= min(decimal_cex, decimal_oracle)"
}
```

前端規則：
- `valid=false`：欄位紅框 + inline message，禁用 Next
- `warning`：欄位黃框 + 可繼續

---

## 5. 必要的狀態顯示

每一步固定顯示：
- `Step Status`: `Not Started` / `In Progress` / `Passed` / `Blocked`
- `Blocking Reasons`（最多 3 條）
- `Warnings`（可展開）

---

## 6. 關鍵校驗（需和 Listing Rules 一致）

- `quote_tick` 精度校驗：
  - 有 CEX：`decimals(quote_tick) <= min(decimal_cex, decimal_oracle)`
  - 無 CEX：`decimals(quote_tick) <= decimal_oracle`
- 單一價格來源（`price_sources = 1`）：
  - `global_max_oi` 降為 50%
  - `max_notional_user` 降為 50%
  - 槓桿收緊（上限 5x）
- IF 最低需求：
  - 以 `Global Max OI_adjusted` 計算 `min_IF`
  - 頁面顯示 `required_IF`, `current_IF`, `gap`

---

## 7. 失敗與重試 UX

- `BLOCK` 類錯誤：固定展示 `原因 + 建議操作`
- 網路錯誤：保留已填值，提供 `Retry`
- 接口超時：顯示 `Still checking...`，30 秒後可手動重試

---

## 8. 提交前最終檢查（Submit Gate）

提交按鈕啟用條件：
- 所有 required 欄位 `valid=true`
- Account check 全部 pass
- `decision != BLOCK`
- 用戶勾選風險與條款確認

不符合時，按鈕保持 disabled，顯示第一個阻斷原因。
