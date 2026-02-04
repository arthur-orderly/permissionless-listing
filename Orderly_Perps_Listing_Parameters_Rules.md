# Orderly Perps 上架參數與規則

## 1. 參考資源

參考交易所：
- Binance: [交易規則](https://www.binance.com/en/futures/trading-rules/perpetual) | [Funding 歷史](https://www.binance.com/en/futures/funding-history/perpetual/real-time-funding-rate)
- WOO: [公開資訊](https://api.woo.org/v1/public/info)
- Bybit: [交易參數](https://www.bybit.com/en/announcement-info/transact-parameters) | [Funding Rate](https://www.bybit.com/en/announcement-info/fund-rate/)
- OKX: [永續合約資訊](https://www.okx.com/trade-market/info/swap) | [Funding Swap](https://www.okx.com/trade-market/funding/swap)

---

## 2. 上架參數指南

| 參數 | 說明 | 設定規則 | 警示/備註 |
|:-----|:-----|:---------|:----------|
| Base_ccy | Token 名稱 | 查詢 CoinGecko/CMC 現貨上架的 Token 名稱 | 若 CEX 現貨名稱不同則警示（可能導致價格錯誤） |
| quote_min | 最小訂單價格 | 設為 `0` | - |
| quote_max | 最大訂單價格 | 設為 `100,000`<br>例外：BTC 設為 `200,000` | - |
| quote_tick | 最小價格變動單位 | 參考其他 CEX 合約的 `quote_tick`<br>注意：處理倍數型（如 `1000PEPE`） | 若 `quote_tick / price > 1%` 則警示 |
| base_min | 最小訂單數量 | 參考其他 CEX<br>確保 `base_min × price` 滿足 `min_notional`（約 10 USDC） | 避免極端值 |
| base_max | 最大訂單數量 | 標準上限：<br>• $3m：BTC, ETH, SOL<br>• $1m：市值前 20<br>• $500k：市值前 100<br><br>市值規則：<br>• < $25m：~$50k **（若 2% 深度 < $10k，降至 $10k）**<br>• $25m - $50m：~$75k<br>• $50m - $75m：~$100k<br>• $75m - $100m：~$125k<br>• > $100m：~$150k | 設定市值追蹤警示 |
| base_tick | 最小數量變動單位 | 參考其他 CEX 合約的 `base_tick`<br>（通常與 `base_min` 相同） | - |
| min_notional | 最小訂單名目金額 | 設為 `10` | - |
| price_range | 價格範圍 | 新上架 (TGE)：第一天設 `0.1` (10%)（與 MM 確認後隔天降低）<br>標準：<br>• 20x 槓桿：`3%`<br>• 10x 槓桿：`5%` | - |
| price_scope | 價格範圍係數 | 設為 `0.6` | - |
| IMR | 初始保證金率 | 公式：`1 / max_leverage`<br>新上架 (TGE)：設為 `0.2`（最高 5x）<br>市值 < $30m：建議設 `0.2`（最高 5x）<br>市值 > $30m：依上架團隊規則（最大值 `0.1` / 10x） | - |
| MMR | 維持保證金率 | 公式：`IMR / 2`<br>例外：若 `IMR = 0.1` 且市值 < $100m，設 `MMR = 0.06`（而非 0.05） | - |
| Max Notional (DMM) | DMM 最大名目金額 | 設為 `1,000,000,000,000`（無限制） | - |
| Max Notional (User) | 用戶最大名目金額 | 依市值：<br>• < $25m：~$75k<br>• $25m - $50m：~$100k<br>• $50m - $75m：~$150k<br>• $75m - $100m：~$200k<br>• $100m - $200m：~$250k<br>• $200m - $600m：~$500k<br>• $600m - $1B：~$500k<br>• > $1B：~$1m<br><br>深度檢查：若各 CEX ±2% 深度最大值 < $10k，降至 ~$50k | 設定市值追蹤警示 |
| IMR_Factor | 保證金縮放係數 | - | - |
| Funding Period | Funding 週期 | 查詢 Funding 間隔。優先順序：Binance > OKX > Bybit | - |
| Funding Cron | Funding 排程 | `CEX 間隔小時數 × 3600`<br>• 1h：`3600`（`0 0 * * * ?`）<br>• 4h：`0 0 0,4,8,12,16,20 * * ?`<br>• 8h：`0 0 0,8,16 * * ?` | - |
| Funding Cap | Funding 上限 | `主要 CEX Funding Cap × (Orderly 週期 / CEX 週期)`<br>優先順序：Binance > Bybit > OKX<br>備用：若僅在二線 CEX 上架，設為 `4%`（例：`2% × (8/4) = 4%`） | - |
| Funding Floor | Funding 下限 | `主要 CEX Funding Floor × (Orderly 週期 / CEX 週期)` | - |
| Interest Rate | 利率 | 與 CEX 相同（標準 `0.01%`）<br>注意：固定使用 8h/0.01%，程式會處理其他週期的轉換 | - |
| Cap/Floor Interest | 利率上下限 | `(Orderly 週期 / CEX 週期) × 0.01%`（Floor 為負值） | - |
| Mark Price Max Dev | 標記價格最大偏差 | `Roundup(5.25% / Orderly Funding Cap, 3)`<br>範例：`5.25% / 4%` = 1.3125 → `1.313` | - |
| Unitary Funding Rounding | Funding 四捨五入精度 | 邏輯：`min_funding_rate <= 10^-5`<br>設定：`config_suf >= min(10^-6, min_funding_rate)`<br>參考 [Tech] Funding Rounding Scale 表格 | - |
| Slope Parameters | 利率曲線參數 | • `Slope1`: 1<br>• `Slope2`: 2<br>• `Slope3`: 4<br>• `p1`: 0.5%<br>• `p2`: 1.5% | - |
| impact_margin_notional | 衝擊保證金名目值 | • 槓桿 > 10x：`1000`<br>• 5x < 槓桿 ≤ 10x：`500`<br>• 槓桿 ≤ 5x：`100`<br>• 熱門 TGE（>1B 市值, 5x）：`500` | - |
| std_liquidation_fee | 標準清算費 | • 槓桿 ≤ 10x：`2.4%`<br>• 槓桿 ≥ 20x：`1.5%`<br>• 槓桿 ≥ 50x：`0.8%` | - |
| liquidator_fee | 清算人費用 | `std_liquidation_fee / 2` | - |
| claim_insurance_fund_discount | IF 折扣 | • 槓桿 ≤ 10x：`1%`<br>• 槓桿 ≥ 20x：`0.75%`<br>• 槓桿 ≥ 50x：`0.4%` | - |
| Index Price Weights | 指數價格權重 | 查詢 CoinGecko/CMC 現貨交易量（最多 7 個來源）<br>`Weight(CEX1) = Volume(CEX1) / Sum(Volumes)` | - |
| bbo valid interval | BBO 有效間隔 | • Binance/Bybit/OKX：`10`<br>• MEXC/Gate：`20`<br>• 其他：`30` | - |
| trade valid interval | 交易有效間隔 | 設為 `7,200` | - |
| Index quote_tick | 指數價格精度 | 與 Symbol 的 `quote_tick` 相同 | - |
| Price (Input) | 價格輸入 | Symbol 的現貨價格 | - |

---

## 3. 上架要求

### 3.1 價格來源要求

| 上架類型 | 最少來源數 | 建議來源 |
|---------|-----------|---------|
| 標準上架 (Standard) | 3 | Binance, Bybit, OKX, WOO, MEXC, Gate |
| **無許可上架 (Permissionless)** | **1** | 同上，但允許單一來源 |

**備註：**
- 盡量避免使用 HTX
- 若來源數 > 3 但交易量極低且 CoinGecko/CMC 有紅旗警告，則忽略該來源
- Permissionless Listing 僅需 1 個價格來源，但建議盡可能提供多個來源以降低價格操縱風險

---

## 4. 風控參數

### 4.1 保險基金 (IF) 要求

#### IF Rate 計算

| 市值層級 | 市值範圍 | 基礎 IF Rate |
|---------|---------|-------------|
| T1 | > $1B | 3% |
| T2 | $500m - $1B | 4% |
| T3 | $100m - $500m | 5% |
| T4 | $25m - $100m | 7% |
| T5 | < $25m | 10% |

**槓桿調整係數：**

| 最大槓桿 | IMR | 調整係數 | 說明 |
|---------|-----|---------|------|
| ≤ 5x | 20% | 1.5x | 低槓桿通常用於高風險幣種，需更高 IF 覆蓋 |
| ≤ 10x | 10% | 1.2x | - |
| ≤ 20x | 5% | 1.0x | 標準 |
| > 20x | < 5% | 0.8x | 高槓桿通常用於穩定幣種 |

**最終 IF Rate = 基礎 IF Rate × 槓桿調整係數**

| 市值 \ 槓桿 | ≤ 5x | ≤ 10x | ≤ 20x | > 20x |
|------------|------|-------|-------|-------|
| T1 (> $1B) | 4.5% | 3.6% | 3.0% | 2.4% |
| T2 ($500m-$1B) | 6.0% | 4.8% | 4.0% | 3.2% |
| T3 ($100m-$500m) | 7.5% | 6.0% | 5.0% | 4.0% |
| T4 ($25m-$100m) | 10.5% | 8.4% | 7.0% | 5.6% |
| T5 (< $25m) | 15.0% | 12.0% | 10.0% | 8.0% |

#### IF 餘額要求公式

```
IF Balance >= Σ (Global Max OI of Symbol_i × IF Rate_i)
```

#### IF 餘額狀態與系統動作

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | >= 120% min | 正常運作 |
| Warning | < 120% min | 通知項目方補充 IF |
| Limit | < 80% min | Reduce-only mode（僅允許減倉） |
| Emergency | < 50% min | Emergency Delist |

> **簡化說明**：移除原本過多的中間狀態（Caution, Critical），保留 3 個主要門檻便於監控與執行

---

### 4.2 清算帳戶 (Liquidation Account) 要求

#### Liq Rate（依槓桿）

| 最大槓桿 | IMR | Liq Rate |
|---------|-----|----------|
| ≤ 5x | 20% | 2.5% |
| ≤ 10x | 10% | 2.0% |
| ≤ 20x | 5% | 1.5% |
| > 20x | < 5% | 1.0% |

#### 併發係數（依 Global Max OI）

| Global Max OI | Concurrent Factor | 說明 |
|---------------|-------------------|------|
| < $100k | 2 | 小規模，同時清算數較少 |
| $100k - $500k | 3 | - |
| $500k - $1m | 4 | - |
| > $1m | 5 | 大規模，需處理更多同時清算 |

#### Liq 餘額要求公式

```
Liq Balance >= Max(
    Global Max OI × Liq Rate,
    User Max Notional × IMR × Concurrent Factor
)
```

#### Liq 餘額狀態與系統動作

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | >= 120% min | 正常運作 |
| Warning | < 120% min | 通知項目方補充 |
| Limit | < 80% min | 暫停清算執行，等待補充 |
| Emergency | < 50% min | Emergency Delist |

---

### 4.3 做市商帳戶 (MM Account) 要求

#### MM Rate（依槓桿）

| 最大槓桿 | IMR | MM Rate (≈ IMR × 1.25) |
|---------|-----|------------------------|
| ≤ 5x | 20% | 25% |
| ≤ 10x | 10% | 12.5% |
| ≤ 20x | 5% | 6.25% |
| > 20x | < 5% | 5% |

#### Buffer（依 Global Max OI）

| Global Max OI | Buffer |
|---------------|--------|
| < $100k | $5,000 |
| $100k - $500k | $10,000 |
| $500k - $1m | $20,000 |
| > $1m | $50,000 |

#### MM 餘額要求公式

```
MM Balance >= (Global Max OI × MM Rate) + Buffer
```

#### MM Requirement（做市要求）

> **TODO**: Permissionless Listing 的 MM Requirement 定義待確認

**現有 Standard Listing 的 MM Requirement 結構參考：**

```sql
-- mm_requirement: 多層級點差與深度要求
mm_requirement (symbol, account, type, spread, bid_level, ask_level, bid_amount, ask_amount)

-- mm_config: 做市在線時間要求
mm_config (account, symbol, start_date, sample_seconds, uptime_pct)
```

| 欄位 | 說明 |
|------|------|
| spread | 點差層級（bps），如 30, 40, 50, 100, 1000 |
| bid_amount / ask_amount | 該點差範圍內的買/賣掛單量要求 |
| bid_level / ask_level | 掛單層級數 |
| sample_seconds | 採樣間隔（秒） |
| uptime_pct | 正常運行時間百分比要求（如 80%） |

**範例（供參考）：**

| Spread (bps) | Bid Amount | Ask Amount | 說明 |
|--------------|------------|------------|------|
| 30 | $1,000 | $1,000 | ±0.3% 範圍內需 $1k 深度 |
| 40 | $5,000 | $5,000 | ±0.4% 範圍內需 $5k 深度 |
| 50 | $5,000 | $5,000 | ±0.5% 範圍內需 $5k 深度 |
| 100 | $25,000 | $25,000 | ±1% 範圍內需 $25k 深度 |
| 1000 | $25,000 | $25,000 | ±10% 範圍內需 $25k 深度 |

**待確認項目：**
- [ ] Permissionless 是否沿用相同的 MM Requirement 結構？
- [ ] 不同市值層級的 MM Requirement 預設值？
- [ ] 項目方可否自訂 MM Requirement？
- [ ] Uptime 要求是否相同（80%）？

---

#### MM 餘額狀態與系統動作（僅 Permissionless）

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | >= 100% min | 正常運作 |
| Warning | < 100% min | 通知項目方補充 |
| Limit | < 50% min（持續 30 分鐘） | Reduce-only mode |

> **備註**：Standard Listing 由平台 MM 負責，不需監控；Permissionless 由項目方自行做市，需監控餘額

---

### 4.4 流動性深度要求

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ±2% 深度 >= $10,000 | 正常交易 |
| Warning | ±2% 深度 < $10,000 | 通知項目方 |
| Limit | ±2% 深度 < $5,000（持續 10 分鐘） | Reduce-only mode |

**低流動性調整規則：**
- 若 CEX 2% 深度 < $10k → 降低 `base_max` 至 $10k
- 若 CEX 2% 深度 < $10k → 降低 `User Max Notional` 至 $50k

---

### 4.5 價格來源監控

#### 標準上架 (Standard Listing)

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | >= 2 個有效來源 | 正常運作 |
| Warning | 來源間偏離 > 3% | 警報 + 人工審核 |
| Limit | 僅剩 1 個有效來源 | 警報 + 密切監控 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

#### 無許可上架 (Permissionless Listing)

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | >= 1 個有效來源 | 正常運作 |
| Warning | 價格凍結 > 1 分鐘 | 警報 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

**單一價格來源的額外限制（Permissionless）：**

| 限制項目 | 多來源 (>=2) | 單一來源 (=1) |
|---------|-------------|--------------|
| Global Max OI 上限 | 依市值規則 | 降低 50% |
| User Max Notional | 依市值規則 | 降低 50% |
| 價格偏離檢查 | 來源間比對 | 與 24h VWAP 比對 |

**其他價格檢查：**
- 價格凍結 > 1 分鐘 → 警報
- 價格與 24h VWAP 偏離 > 50% → 自動暫停交易
- 價格 5 分鐘內變動 > 30% → 暫停新開倉 10 分鐘

---

### 4.6 Funding Rate 監控

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | Funding Rate 在 Cap/Floor 範圍內 | 正常運作 |
| Warning | 連續 3 個週期達到 Cap 或 Floor | 警報 + 通知項目方 |
| Limit | 連續 6 個週期達到 Cap 或 Floor | 警報 + 人工審核 |

**異常情境處置：**

| 情境 | 說明 | 處置 |
|------|------|------|
| 長期正 Funding | 連續 24hr Funding > 0.1%/8hr | 檢查是否有價格操縱或流動性問題 |
| 長期負 Funding | 連續 24hr Funding < -0.1%/8hr | 檢查是否有異常空頭壓力 |
| Funding 異常波動 | 單週期 Funding 變化 > 0.5% | 警報 + 檢查價格來源 |

---

### 4.7 Global Max OI 限制總表

| 上架類型 | 價格來源數 | Global Max OI | User Max Notional |
|---------|-----------|---------------|-------------------|
| Standard | >= 3 | 依市值規則 100% | 依市值規則 100% |
| Permissionless | >= 2 | 依市值規則 100% | 依市值規則 100% |
| Permissionless | = 1 | 依市值規則 **50%** | 依市值規則 **50%** |

---

### 4.8 上架前驗證清單

| 檢查項目 | 驗證方式 | 失敗處置 |
|---------|---------|---------|
| CoinGecko/CMC ID | API 查詢 | 拒絕上架 |
| 合約地址比對 | 鏈上驗證 | 拒絕上架 |
| Token 供應量驗證 | 鏈上查詢 | 拒絕上架 |
| Token 年齡 | 合約部署 > 30 天 | 需人工審核 |
| 持有者分佈 | 前 10 大持有者 < 80% 供應量 | 風險警示 |
| 黑名單檢查 | 內部資料庫 | 拒絕上架 |
| 制裁名單檢查 | OFAC、UN 名單 | 拒絕上架 |
| IF 餘額 | >= 最低要求 | 拒絕上架 |
| Liq 餘額 | >= 最低要求 | 拒絕上架 |
| MM 餘額 | >= 最低要求 | 拒絕上架 |
| 價格來源 | >= 1 個有效來源（Permissionless） | 拒絕上架 |

---

### 4.9 上架後監控總表

| 監控項目 | 適用範圍 | 檢查頻率 | Warning | Limit | Emergency |
|---------|---------|---------|---------|-------|-----------|
| IF 餘額 | All | 1 分鐘 | < 120% min | < 80% min | < 50% min |
| Liq 餘額 | All | 1 分鐘 | < 120% min | < 80% min | < 50% min |
| MM 餘額 | Permissionless | 1 分鐘 | < 100% min | < 50% min（持續 30 分鐘） | - |
| 流動性深度 | All | 1 分鐘 | < $10k | < $5k（持續 10 分鐘） | - |
| 價格來源數 | Standard | 10 秒 | 偏離 > 3% | 僅剩 1 個來源 | 0 個來源 |
| 價格來源數 | Permissionless | 10 秒 | 凍結 > 1 分鐘 | - | 0 個來源 |
| 價格更新 | All | 10 秒 | 凍結 > 1 分鐘 | - | 所有來源失效 |
| 價格波動 | All | 即時 | - | 5 分鐘內 > 30% | - |
| 清算頻率 | All | 1 小時 | > 10 次/小時 | > 20 次/小時 | > 20% OI/小時 |
| Funding Rate | All | 每週期 | 連續 3 週期達 Cap/Floor | 連續 6 週期達 Cap/Floor | - |

---

## 5. 附錄：與 PRD 同步事項

| 項目 | 本文件 | 建議同步至 PRD |
|------|--------|---------------|
| IF 狀態數量 | 4 個（Normal/Warning/Limit/Emergency） | 統一為 4 個，移除 Caution/Critical |
| MM Account 監控 | 僅 Permissionless 需監控 | 需同步 |
| Funding Rate 監控 | 已新增 | 需同步 |
| 單一價格來源限制 | Max OI 降低 50% | 需同步 |
