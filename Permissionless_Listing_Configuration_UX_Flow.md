# Permissionless Listing Configuration UX Flow

## 1. 目標

定義「用戶先填入關鍵參數，系統查詢接口，再依返回結果引導後續填寫」的配置流程，前後端對齊同一套 gate 規則。

---

## 2. 流程（Step 1 - Step 4）

### Step 1: 選擇 Symbol
- 用戶操作：輸入 `symbol` 或 `coingecko_api_id`
- 前端行為：送出預檢查並載入配置上下文
- 後端接口：`POST /v1/broker/listing/symbol`
- 重點：若通過，response 必須回傳該 symbol 的可配置欄位、限制範圍、預設值

### Step 2: 填寫 Broker 可配參數
- 用戶操作：填寫 Broker 可配欄位（如 `quote_tick`, `base_min`, `imr`, `max_notional_user`）
- 前端行為：每次欄位變更做即時校驗；按 Next 前做整體校驗
- 後端接口：`POST /v1/broker/listing/pre_check`
- 條件：所有 required 欄位通過才可進下一步

### Step 3: Preview
- 用戶操作：點擊 Preview
- 前端行為：顯示最終參數、MM Required、IF 最低需求、警示資訊
- 條件：勾選確認後可提交

### Step 4: Submit
- 用戶操作：選擇上架時間 `listing_time`，點擊提交
- 前端行為：建立 NEW，觸發提交流程
- 後端接口：`POST /v1/broker/listing/submit`
- 結果：成功後進 `NEW`

---

## 3. API 詳細規格

### 3.1 `POST /v1/broker/listing/symbol`

用途：取得 symbol 上下文，決定是否允許進入配置。

Request 欄位：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| symbol | string | 二選一 | 交易對基礎幣代碼 |
| coingecko_api_id | string | 二選一 | CoinGecko API id |

Request 規則：
- `symbol`、`coingecko_api_id` 至少填一個
- 若兩者都填，後端需校驗一致性

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
    "quote_tick": {
      "max_decimals": 4,
      "warn_ratio_gt": 0.01
    },
    "imr": {
      "min": 0.1,
      "max": 0.2
    },
    "max_notional_user": {
      "min": 50000,
      "max": 1000000
    }
  },
  "derived": {
    "price_sources": 1,
    "market_cap_rank": 120,
    "global_max_oi_factor": 0.5,
    "user_notional_factor": 0.5,
    "leverage_cap": 5
  }
}
```

Decision 對應前端行為：
- `ALLOW`：直接進 Step 2
- `ALLOW_WITH_WARNINGS`：顯示警示，允許進 Step 2
- `BLOCK`：顯示阻斷原因，不可進 Step 2

Error codes：
- `SYMBOL_NOT_FOUND`
- `BLACKLISTED`
- `RWA_NOT_SUPPORTED`
- `NOT_ELIGIBLE`

---

### 3.2 `POST /v1/broker/listing/pre_check`

用途：欄位級 + 整體校驗。

Request 欄位：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| symbol | string | 是 | 目標 symbol |
| inputs | object | 是 | Broker 填寫參數集合 |
| inputs.quote_tick | string | 視 editable_fields | 最小價格變動單位 |
| inputs.base_min | string | 視 editable_fields | 最小下單數量 |
| inputs.base_tick | string | 視 editable_fields | 最小數量變動單位 |
| inputs.imr | string | 視 editable_fields | 初始保證金率 |
| inputs.max_notional_user | string | 視 editable_fields | User 最大名目 |
| mode | string | 否 | `field` 或 `full`，預設 `full` |

Request 說明：
- `mode=field`：單欄位即時校驗
- `mode=full`：Next 前整體校驗

Response:
```json
{
  "decision": "ALLOW_WITH_WARNINGS",
  "field_results": [
    {
      "field": "quote_tick",
      "valid": false,
      "warning": false,
      "code": "DECIMAL_EXCEED",
      "message": "quote_tick decimals must be <= min(decimal_cex, decimal_oracle)"
    },
    {
      "field": "base_min",
      "valid": true,
      "warning": true,
      "code": "MIN_NOTIONAL_EDGE",
      "message": "close to min_notional boundary"
    }
  ],
  "warnings": ["single source: leverage/notional tightened"],
  "computed": {
    "mm_required": "...",
    "min_if_required": "..."
  }
}
```

前端行為：
- `valid=false`：欄位紅框 + message，禁用 Next
- `warning=true`：欄位黃框 + message，可繼續
- `decision=BLOCK`：整步阻擋

Error codes：
- `SYMBOL_CONTEXT_MISSING`
- `VALIDATION_FAILED`

---

### 3.3 `POST /v1/broker/listing/submit`

用途：提交上架申請。

Request 欄位：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| symbol | string | 是 | 目標 symbol |
| listing_time | string | 是 | 上架時間（ISO 8601） |
| inputs | object | 是 | Step 2 已通過校驗的參數 |
| accounts | object | 是 | 相關子帳戶配置 |
| accounts.if_account | string | 是 | IF 子帳戶 |
| accounts.liq_account | string | 是 | Liquidation 子帳戶 |
| accounts.fee_account | string | 是 | Fee 子帳戶 |
| accounts.mm_accounts | string[] | 是 | MM 子帳戶列表 |
| ack | object | 是 | 提交前確認 |
| ack.risk | boolean | 是 | 風險確認 |
| ack.terms | boolean | 是 | 條款確認 |

Response:
```json
{
  "listing_id": "LST_12345",
  "status": "NEW",
  "next_status": "PENDING"
}
```

Error codes：
- `PRECHECK_REQUIRED`
- `ACCOUNT_INSUFFICIENT`
- `LISTING_TIME_INVALID`
- `CONFLICTING_REQUEST`

---

## 4. 提交 Gate（前端）

提交按鈕啟用條件：
- required 欄位全部 `valid=true`
- `decision != BLOCK`
- 帳戶檢查通過
- `ack.risk=true` 且 `ack.terms=true`

未滿足條件時：
- 按鈕 disabled
- 顯示第一個阻斷原因

---

## 5. 與 Listing Rules 對齊項目

- `quote_tick` 精度校驗：
  - 有 CEX：`decimals(quote_tick) <= min(decimal_cex, decimal_oracle)`
  - 無 CEX：`decimals(quote_tick) <= decimal_oracle`
- `price_sources=1` 時：
  - `global_max_oi` 降為 50%
  - `max_notional_user` 降為 50%
  - `max_leverage` 上限收斂為 5x
- IF 最低需求：以 `Global Max OI_adjusted` 計算 `min_IF`

---

## 6. 錯誤與重試 UX

- `BLOCK`：顯示阻斷原因 + 建議操作
- 網路失敗：保留已填值 + Retry
- 超時：顯示 checking 狀態，30 秒後允許手動重試
