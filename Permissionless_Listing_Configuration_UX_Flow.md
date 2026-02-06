# Permissionless Listing Configuration UX Flow

## 1. 目標

定義「用戶先填入關鍵參數，系統查詢接口，再依返回結果引導後續填寫」的配置流程， 前後端對齊同一套 gate 規則。
---

---

## 3. 設置流程

### Step 1: 選擇Symbol
- 用戶操作: 輸入 `symbol` 或 `coingecko_api_id`
- 前端行為: 送出預檢查並載入配置上下文
- 後端接口: `POST /v1/broker/listing/symbol`
  - 通過的話會回傳這個symbol的參數範圍在response


### Step 2: 填寫Broker可配參數
- 用戶操作: 填寫 Broker 可配欄位（如 `quote_tick`, `base_min`, `IMR`, `Max Notional(User)`）
- 前端行為: 每次欄位變更做即時校驗
- 後端接口: `POST /v1/broker/listing/pre_check`
- 條件: 所有 required 欄位都通過才可進入下一步

### Step 3: Preview
- 用戶操作: Preview 
- 前端行為: 顯示最終參數與MM Required
- 條件: 勾選確認後可提交

### Step 4: Submit
- 用戶操作: 選擇上架時間，點擊提交
- 前端行為: 建立 NEW，觸發 pre-check
- 後端接口: `POST /v1/broker/listing/submit`
- 結果: 成功後進 NEW

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
