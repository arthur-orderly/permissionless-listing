# Permissionless Listing Configuration UX Flow

## 1. 目標

定義「用戶先填入關鍵參數，系統查詢接口，再依返回結果引導後續填寫」的配置流程，前後端對齊同一套 gate 規則。

---

## 2. 流程（Step 1 - Step 4）

### Step 1: 選擇 Symbol
- 用戶操作：輸入 `symbol` 或 `api_id`
- 前端行為：送出預檢查並載入配置上下文
- 後端接口：`POST /v1/broker/listing/symbol`
- 條件：接口回傳 通過 才可進 Step 2

### Step 2: 填寫 Broker 可配參數
- 用戶操作：填寫 Broker 可配欄位
- 前端行為：每次欄位變更做即時校驗
- 後端接口：`POST /v1/broker/listing/pre_check`
- 條件：所有 required 欄位都通過才可進入下一步

### Step 3: Preview
- 用戶操作：點擊 Preview
- 前端行為：顯示最終參數與 MM Required / Min IF Required
- 條件：勾選確認後可提交

### Step 4: Submit
- 用戶操作：選擇上架時間，點擊提交
- 前端行為：建立 NEW，觸發 pre-check
- 後端接口：`POST /v1/broker/listing/submit`
- 結果：成功後進 `NEW`

---

## 3. API 規格

### 3.1 `POST /v1/broker/listing/symbol`

用途：取得 Symbol 配置上下文，決定是否可進入配置。

Request：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| symbol | string | 二選一 | 交易對基礎幣代碼 |
| api_id | string | 二選一 | CoinGecko API ID |

Request 規則：
- `symbol`、`api_id` 至少填一個
- 若兩者都填，以api_id為主

Response：

| 欄位 | 型別 | 說明 |
|------|------|------|
| success | boolean | 是否成功 |
| timestamp | integer | 毫秒時間戳 |
| data.decision | string | `ALLOW` / `ALLOW_WITH_WARNINGS` / `BLOCK` |
| data.reasons | string[] | 阻擋或收斂原因碼 |
| data.warnings | string[] | 警示文案 |
| data.editable_fields | string[] | Broker 可填欄位 |
| data.locked_fields | string[] | 僅展示不可填欄位 |
| data.defaults | object | 預設值集合 |
| data.defaults.min_notional | number | 最小名目預設值 |
| data.defaults.price_scope | number | 價格範圍係數預設值 |
| data.constraints | object | 欄位限制集合 |
| data.constraints.quote_tick.max_decimals | integer | `quote_tick` 最大小數位 |
| data.constraints.quote_tick.warn_ratio_gt | number | `quote_tick / price` 警示門檻 |
| data.constraints.imr.min | number | `imr` 下限 |
| data.constraints.imr.max | number | `imr` 上限 |
| data.constraints.max_notional_user.min | number | `max_notional_user` 下限 |
| data.constraints.max_notional_user.max | number | `max_notional_user` 上限 |
| data.derived | object | 派生結果（前端展示） |
| data.derived.price_sources | integer | 有效價格來源數 |
| data.derived.market_cap_rank | integer | 市值排名 |
| data.derived.global_max_oi_factor | number | `global_max_oi` 調整係數 |
| data.derived.user_notional_factor | number | `max_notional_user` 調整係數 |
| data.derived.leverage_cap | number | 槓桿上限 |

Decision 對應前端行為：
- `ALLOW`：直接進 Step 2
- `ALLOW_WITH_WARNINGS`：顯示警示，允許進 Step 2
- `BLOCK`：顯示阻斷原因，不可進 Step 2

可能錯誤碼：
- `SYMBOL_NOT_FOUND`
- `BLACKLISTED`
- `RWA_NOT_SUPPORTED`
- `NOT_ELIGIBLE`

---

### 3.2 `POST /v1/broker/listing/pre_check`

用途：欄位級與整體校驗。

Request：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| symbol | string | 是 | 目標 symbol |
| mode | string | 否 | `field` 或 `full`，預設 `full` |
| validate_field | string | 否 | `mode=field` 時必填，指定校驗欄位 |
| inputs | object | 是 | Broker 填寫參數集合 |
| inputs.quote_tick | string | 視 editable_fields | 最小價格變動單位 |
| inputs.base_min | string | 視 editable_fields | 最小下單數量 |
| inputs.base_tick | string | 視 editable_fields | 最小數量變動單位 |
| inputs.imr | string | 視 editable_fields | 初始保證金率 |
| inputs.max_notional_user | string | 視 editable_fields | User 最大名目 |

Request 規則：
- `mode=field`：僅驗單欄位（即時校驗）
- `mode=full`：驗整份輸入（Next 前校驗）

Response：

| 欄位 | 型別 | 說明 |
|------|------|------|
| success | boolean | 是否成功 |
| timestamp | integer | 毫秒時間戳 |
| data.decision | string | `ALLOW` / `ALLOW_WITH_WARNINGS` / `BLOCK` |
| data.field_results | object[] | 欄位級校驗結果 |
| data.field_results[].field | string | 欄位名稱 |
| data.field_results[].valid | boolean | 是否通過 |
| data.field_results[].warning | boolean | 是否為警示 |
| data.field_results[].code | string | 校驗碼 |
| data.field_results[].message | string | 提示文案 |
| data.warnings | string[] | 整體警示 |
| data.computed | object | 衍生結果 |
| data.computed.mm_required | string | MM Requirement 摘要 |
| data.computed.min_if_required | string | 最低 IF 需求 |

Decision 對應前端行為：
- 任一 `field_results[].valid=false`：欄位紅框，禁用 Next
- 任一 `field_results[].warning=true`：欄位黃框，可繼續
- `data.decision=BLOCK`：整步阻擋

可能錯誤碼：
- `SYMBOL_CONTEXT_MISSING`
- `VALIDATION_FAILED`

---

### 3.3 `POST /v1/broker/listing/submit`

用途：提交上架申請。

Request：

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

Response：

| 欄位 | 型別 | 說明 |
|------|------|------|
| success | boolean | 是否成功 |
| timestamp | integer | 毫秒時間戳 |
| data.listing_id | string | 上架申請 ID |
| data.status | string | 建立後狀態（固定 `NEW`） |
| data.next_status | string | 預期下一狀態（例：`PENDING`） |
| data.submit_time | string | 申請送出時間（ISO 8601） |

可能錯誤碼：
- `PRECHECK_REQUIRED`
- `ACCOUNT_INSUFFICIENT`
- `LISTING_TIME_INVALID`
- `CONFLICTING_REQUEST`

---

## 4. 前端 Gate 規則

提交按鈕啟用條件：
- required 欄位全部 `valid=true`
- `data.decision != BLOCK`
- 帳戶檢查通過
- `ack.risk=true` 且 `ack.terms=true`

未滿足條件：
- 按鈕 disabled
- 顯示第一個阻斷原因

---

## 5. 與 Listing Rules 對齊

- `quote_tick` 精度校驗：
  - 有 CEX：`decimals(quote_tick) <= min(decimal_cex, decimal_oracle)`
  - 無 CEX：`decimals(quote_tick) <= decimal_oracle`
- 價格來源數 (`price_sources`) 影響風控上限：
  - `price_sources=1`：`global_max_oi`、`max_notional_user`、`max_leverage` 需收斂
  - `price_sources>=2`：可使用標準上限
- IF 最低需求：以調整後 `global_max_oi` 計算 `min_if_required`

---

## 6. 錯誤與重試 UX

- `BLOCK`：顯示阻斷原因與修正方向
- 網路失敗：保留已填值並允許 Retry
- 超時：顯示 checking 狀態，30 秒後可手動重試
