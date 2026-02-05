# Orderly Perps 上架參數與規則

> 相關文件：[Permissionless Listing PRD](./PRD-chinese.md) | [Frontend Requirements](./Permissionless_Listing_Frontend_Requirements.md) | [Slashing System](./Slashing_System.md)

---

## 1. 概述與參考資源

### 1.1 參考交易所

- Binance: [交易規則](https://www.binance.com/en/futures/trading-rules/perpetual) | [Funding 歷史](https://www.binance.com/en/futures/funding-history/perpetual/real-time-funding-rate)
- Bybit: [交易參數](https://www.bybit.com/en/announcement-info/transact-parameters) | [Funding Rate](https://www.bybit.com/en/announcement-info/fund-rate/)
- OKX: [永續合約資訊](https://www.okx.com/trade-market/info/swap) | [Funding Swap](https://www.okx.com/trade-market/funding/swap)
- CoinGecko API: [coins/markets](https://api.coingecko.com/api/v3/coins/markets) | [search](https://api.coingecko.com/api/v3/search)

### 1.2 價格來源要求

| 上架類型 | 最少來源數 | 說明 |
|---------|-----------|------|
| Standard | 3 | Binance, Bybit, OKX, MEXC, Gate, Pyth, Stork |
| Permissionless | 1 | 同上，但允許單一來源（需收緊槓桿與名目限額，見 2.3.2） |

**支援的價格來源：**
BINANCE, HUOBI, OKX, GATEIO, BYBIT, KUCOIN, COINBASE, MEXC, BITGET, BINGX, HYPERLIQUID, WOOX, LBANK

**Oracle：** PYTH, STORK

**備註：**
- 若來源數 > 3 但交易量極低且 CoinGecko 有紅旗警告，則忽略該來源

---

## 2. 參數設定規則

### 參數總表

| 參數 | 來源 | 說明 |
|------|------|------|
| base_ccy | Broker  | Symbol Name |
| max_leverage | Broker  | 最大槓桿（5x / 10x / 20x） |
| global_max_oi | Broker  | 全局最大持倉量 |
| max_notional_user | Broker  | 單用戶最大名目金額 |
| taker_fee_markup | Broker | 手續費加成 |
| maker_fee_markup | Broker | 手續費加成 |
| quote_min | 系統固定 | 0 |
| quote_max | 系統固定 | 100,000（BTC: 200,000） |
| min_notional | 系統固定 | 10 USDC |
| price_scope | 系統固定 | 0.6 |
| max_notional_dmm | 系統固定 | 1,000,000,000,000 |
| interest_rate | 系統固定 | 0.01% per 8h |
| slope_parameters | 系統固定 | slope1=1, slope2=2, slope3=4, p1=0.5%, p2=1.5% |
| trade_valid_interval | 系統固定 | 7,200 秒 |
| liquidation_fee_rate | 系統計算 | 依槓桿，詳見 2.3.5 |
| base_min | 系統計算 | 依 oracle price 計算 |
| base_tick | 系統計算 | 依 CEX 或 base_min |
| quote_tick | 系統計算 | 依 CEX / Oracle 小數位 |
| index_source | 系統計算 | 依可用價格來源 |
| imr | 系統計算 | 依 Max Leverage |
| mmr | 系統計算 | 依 imr / market cap |
| price_range | 系統計算 | 依 TGE / 槓桿 |
| base_max | 系統計算 | 依市值 / 排名 |
| impact_margin_notional | 系統計算 | 依槓桿 / TGE |
| funding_parameters | 系統計算 | 依 CEX 資料 |
| index_weight / bbo_interval | 系統計算 | 依交易所 / 交易量 |

---

### 2.1 Broker 可配參數

以下參數由 Broker 自行設定，系統進行驗證：

| 參數 | 驗證規則 | 警示 |
|------|---------|------|
| base_ccy | 必須能在 CoinGecko API 中找到 | - |
| max_leverage | 用戶從 5x / 10x / 20x 中選擇，系統依條件限制（見下方） | - |
| global_max_oi | 不可超過 IF 餘額反算的上限（見 3.1） | - |
| max_notional_user | 不可超過 Global Max OI 的 5% | - |
| taker_fee_markup | 0 - 5 bps，預設 0 bps | - |
| maker_fee_markup | 0 - 2 bps，預設 0 bps | - |

#### 2.1.1 Max Leverage 選項與限制

用戶從以下選項中選擇，系統根據條件自動限制可選範圍：

| 條件 | 可選選項 | IMR | 說明 |
|------|---------|-----|------|
| TGE 新上架 | 5x only | 20% | 強制 5x，不可選更高 |
| 市值 < $30m | 5x only | 20% | 強制 5x，不可選更高 |
| 市值 $30m - $100m | 5x / 10x | 20% / 10% | 最高 10x |
| 市值 > $100m | 5x / 10x / 20x | 20% / 10% / 5% | 最高 20x |

#### 2.1.2 手續費加成 (Fee Markup)

每個 Symbol 可獨立配置手續費率加成，加成為用戶支付手續費的額外比例（bps）。手續費分潤 (Fee Share) 依據用戶實際支付的總手續費（含加成）進行計算，也會影響Referral的計算

| 參數 | 範圍 | 預設 | 說明 |
|------|------|------|------|
| taker_fee_markup | 0 - 5 bps | 0 bps | Taker 額外手續費 |
| maker_fee_markup | 0 - 2 bps | 0 bps | Maker 額外手續費 |

---

### 2.2 固定參數

以下參數為系統固定值，Broker 不可修改：

| 參數 | 值 | 備註 |
|------|-----|------|
| quote_min | 0 | - |
| quote_max | 100,000（BTC: 200,000） | - |
| min_notional | 10 | USDC |
| price_scope | 0.6 | - |
| max_notional_dmm | 1,000,000,000,000 | 無限制 |
| interest_rate | 0.01% per 8h | 與 CEX 相同，固定基準值 |
| slope_parameters | slope1=1, slope2=2, slope3=4, p1=0.5%, p2=1.5% | - |
| trade_valid_interval | 7,200 | 秒 |

---

### 2.3 計算型參數

以下參數由系統根據 Broker 輸入與市場數據自動計算，Broker 不可修改。

#### 2.3.1 價格與下單

**quote_tick：**
- 有 CEX 參考時：小數位數取 `min(CEX 小數位, Oracle 小數位)`
- 無 CEX 參考時：取 Oracle 小數位
- 若 `quote_tick / price > 1%` → 警示

**base_min：**
- 有 CEX 參考時：取 CEX 的 base_min
- 無 CEX 參考時：目標價值約 1 USDC（`1 / oracle_price`）
- 驗證：`base_min × price` 必須介於 0.02 ~ 5 USDC

**base_tick：**
- 有 CEX 參考時：取 CEX 的 base_tick
- 無 CEX 參考時：= base_min

**price_range：**

| 條件 | price_range | 說明 |
|------|-------------|------|
| TGE 第一天 | 10% | 隔天降低 |
| max_leverage ≥ 20x | 3% | - |
| max_leverage < 20x | 5% | - |

#### 2.3.2 Notional 與限額

**base_max（依市值排名）：**

| 條件 | base_max |
|------|----------|
| BTC / ETH / SOL | $3,000,000 |
| 市值排名 ≤ 20 | $1,000,000 |
| 市值排名 ≤ 100 | $500,000 |
| 其他依市值分級 | 見下表 |
| 若 CEX ±2% 深度 < $10k | 降至 $10,000 |

**市值分級對照表：**

| 市值範圍 | base_max | User Max Notional |
|---------|----------|-------------------|
| < $25m | ~$50k | ~$75k |
| $25m - $50m | ~$75k | ~$100k |
| $50m - $75m | ~$100k | ~$150k |
| $75m - $100m | ~$125k | ~$200k |
| $100m - $200m | ~$150k | ~$250k |
| $200m - $600m | - | ~$500k |
| $600m - $1B | - | ~$500k |
| > $1B | - | ~$1m |

> 若 CEX ±2% 深度 < $10k → User Max Notional 降至 $50k

**單一價格來源限制：**

| 項目 | 多來源 (≥2) | 單一來源 (=1) |
|------|-------------|--------------|
| Global Max OI | 依市值規則 100% | 降低 50% |
| User Max Notional | 依市值規則 100% | 降低 50% |
| Max Leverage | 依規則 | 上限 5x |
| 價格偏離檢查 | 來源間比對 | 與 24h VWAP 比對 |

#### 2.3.3 槓桿與保證金

**IMR / MMR：**

| 條件 | IMR | MMR | 說明 |
|------|-----|-----|------|
| TGE 或市值 < $30m | 20% | 10% | 強制 5x |
| 市值 ≥ $30m, 10x | 10% | 5% | - |
| 市值 ≥ $30m, 10x, 市值 < $100m | 10% | 6% | MMR 例外調高 |
| 市值 ≥ $100m, 20x | 5% | 2.5% | - |

> MMR = IMR / 2（市值 < $100m 且 IMR = 10% 時例外為 6%）

**impact_margin_notional：**

| 條件 | 值 |
|------|-----|
| 熱門 TGE（市值 > $1B, ≤ 5x） | 500 |
| max_leverage > 10x | 1,000 |
| max_leverage > 5x | 500 |
| max_leverage ≤ 5x | 100 |

#### 2.3.4 Funding 與利率

**funding_period：** 查詢 CEX funding 間隔，優先順序 Binance > OKX > Bybit

**funding_cron：**

| 間隔 | Cron 表達式 |
|------|------------|
| 1h | `0 0 * * * ?` |
| 4h | `0 0 0,4,8,12,16,20 * * ?` |
| 8h | `0 0 0,8,16 * * ?` |

**funding_cap / funding_floor：**
- 公式：`CEX Cap × (Orderly 週期 / CEX 週期)`
- 僅在二線 CEX 上架時，預設 cap = 4%

**Interest Rate 與 Cap/Floor Interest：**

Interest Rate 固定為 0.01% per 8h（與 CEX 相同），但 Cap/Floor Interest 需根據 Orderly 實際的 funding 週期換算：

| 參數 | 公式 | 說明 |
|------|------|------|
| interest_rate | 固定 0.01% per 8h | 基準值，與 CEX 相同 |
| cap_interest | `(Orderly 週期 / CEX 週期) × 0.01%` | 正值 |
| floor_interest | `-(Orderly 週期 / CEX 週期) × 0.01%` | 負值 |

**範例：**

| Orderly 週期 | CEX 週期 | cap_interest | floor_interest |
|-------------|---------|--------------|----------------|
| 8h | 8h | +0.01% | -0.01% |
| 4h | 8h | +0.005% | -0.005% |
| 1h | 8h | +0.00125% | -0.00125% |

**其他 Funding 參數：**

| 參數 | 計算方式 | 範例 |
|------|---------|------|
| mark_price_max_dev | `roundup(5.25% / funding_cap, 3)` | 5.25% / 4% = 1.3125 → 1.313 |
| unitary_funding_rounding | `config_suf ≥ min(1e-6, min_funding_rate)` | - |

#### 2.3.5 清算費率

| Max Leverage | std_liquidation_fee | liquidator_fee | claim_IF_discount |
|--------------|---------------------|----------------|-------------------|
| ≤ 10x | 2.4% | 1.2% | 1.0% |
| ≥ 20x | 1.5% | 0.75% | 0.75% |
| ≥ 50x | 0.8% | 0.4% | 0.4% |

> `liquidator_fee = std_liquidation_fee / 2`

#### 2.3.6 指數與行情

**index_price_weight：** 查詢 CoinGecko 現貨交易量（最多 7 個來源），`weight = volume_i / sum(volumes)`

**bbo_valid_interval：**

| 交易所 | interval (秒) |
|--------|--------------|
| Binance / Bybit / OKX | 10 |
| MEXC / Gate | 20 |
| 其他 | 30 |

**index_quote_tick：** 與 symbol 的 quote_tick 相同

---

## 3. 風控帳戶要求

上架前需驗證以下三個帳戶的餘額是否滿足最低要求。

### 3.1 保險基金 (IF Account)

**公式：**
```
IF Balance ≥ Σ (Global Max OI_adjusted_i × IF Rate_i)
```

**IF Rate = Base Rate × Leverage Multiplier**

**Base Rate（依市值）：**

| Tier | 市值範圍 | Base Rate |
|------|---------|-----------|
| T1 | > $1B | 3% |
| T2 | $500m - $1B | 4% |
| T3 | $100m - $500m | 5% |
| T4 | $25m - $100m | 7% |
| T5 | < $25m | 10% |

**Leverage Multiplier：**

| 最大槓桿 | IMR | Multiplier | 說明 |
|---------|-----|------------|------|
| ≤ 5x | 20% | 1.5x | 低槓桿通常用於高風險幣種 |
| ≤ 10x | 10% | 1.2x | - |
| ≤ 20x | 5% | 1.0x | 標準 |
| > 20x | < 5% | 0.8x | 高槓桿通常用於穩定幣種 |

**IF Rate 完整對照表：**

| 市值 \ 槓桿 | ≤ 5x | ≤ 10x | ≤ 20x | > 20x |
|------------|------|-------|-------|-------|
| T1 (> $1B) | 4.5% | 3.6% | 3.0% | 2.4% |
| T2 ($500m-$1B) | 6.0% | 4.8% | 4.0% | 3.2% |
| T3 ($100m-$500m) | 7.5% | 6.0% | 5.0% | 4.0% |
| T4 ($25m-$100m) | 10.5% | 8.4% | 7.0% | 5.6% |
| T5 (< $25m) | 15.0% | 12.0% | 10.0% | 8.0% |

### 3.2 清算帳戶 (Liquidation Account)

**公式：**
```
Liq Balance ≥ Max(
    Global Max OI × Liq Rate,
    User Max Notional × IMR × Concurrent Factor
)
```

**Liq Rate（依槓桿）：**

| 最大槓桿 | IMR | Liq Rate |
|---------|-----|----------|
| ≤ 5x | 20% | 2.5% |
| ≤ 10x | 10% | 2.0% |
| ≤ 20x | 5% | 1.5% |
| > 20x | < 5% | 1.0% |

**Concurrent Factor（依 Global Max OI）：**

| Global Max OI | Concurrent Factor | 說明 |
|---------------|-------------------|------|
| < $100k | 2 | 小規模，同時清算數較少 |
| $100k - $500k | 3 | - |
| $500k - $1m | 4 | - |
| > $1m | 5 | 大規模，需處理更多同時清算 |

### 3.3 做市商帳戶 (MM Account)

**餘額公式：**
```
MM Balance ≥ (Global Max OI × MM Rate) + Buffer
```

**MM Rate（依槓桿，≈ IMR × 1.25）：**

| 最大槓桿 | IMR | MM Rate |
|---------|-----|---------|
| ≤ 5x | 20% | 25% |
| ≤ 10x | 10% | 12.5% |
| ≤ 20x | 5% | 6.25% |
| > 20x | < 5% | 5% |

**Buffer（依 Global Max OI）：**

| Global Max OI | Buffer |
|---------------|--------|
| < $100k | $5,000 |
| $100k - $500k | $10,000 |
| $500k - $1m | $20,000 |
| > $1m | $50,000 |

**做市要求（MM Requirement）：**

> **TODO**: Permissionless Listing 的 MM Requirement 定義待確認

**現有 Standard Listing 結構參考：**

```sql
mm_requirement (symbol, account, type, spread, bid_level, ask_level, bid_amount, ask_amount)
mm_config (account, symbol, start_date, sample_seconds, uptime_pct)
```

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

## 5. 上架後監控

### 5.1 監控總表

| 監控項目 | 頻率 | Warning | Limit | Emergency |
|---------|------|---------|-------|-----------|
| IF 餘額 | 1 分鐘 | < 120% min | < 80% min → Reduce-only | < 50% min → Delist |
| Liq 餘額 | 1 分鐘 | < 120% min | < 80% min → 暫停清算 | < 50% min → Delist |
| MM 餘額 | 1 分鐘 | < 100% min | < 50% min 持續 30 分鐘 → Reduce-only | - |
| 流動性深度 | 1 分鐘 | ±2% < $10k | ±2% < $5k 持續 10 分鐘 → Reduce-only | - |
| 價格來源 | 10 秒 | 凍結 > 1 分鐘 | - | 0 個來源 → 暫停交易 |
| 價格偏離 | 即時 | - | - | 與 24h VWAP 偏離 > 50% → 暫停交易 |
| 清算頻率 | 1 小時 | > 20 次/小時 | > 10% OI/小時 | > 20% OI/小時 |
| Funding Rate | 每週期 | 連續 3 週期達 Cap/Floor | 連續 6 週期達 Cap/Floor | - |

### 5.2 帳戶餘額監控

**IF Account：**

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 120% min_IF | 正常運作 |
| Warning | < 120% min_IF | 通知項目方補充 IF |
| Limit | < 80% min_IF | Reduce-only mode（僅允許減倉） |
| Emergency | < 50% min_IF | Emergency Delist |

**Liquidation Account：**

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 120% min | 正常運作 |
| Warning | < 120% min | 通知項目方補充 |
| Limit | < 80% min | 暫停清算執行，等待補充 |
| Emergency | < 50% min | Emergency Delist |

**MM Account（僅 Permissionless）：**

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 100% min | 正常運作 |
| Warning | < 100% min | 通知項目方補充 |
| Limit | < 50% min（持續 30 分鐘） | Reduce-only mode |

> Standard Listing 由平台 MM 負責，不需監控 MM 餘額

### 5.3 流動性深度監控

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ±2% 深度 ≥ $10,000 | 正常交易 |
| Warning | ±2% 深度 < $10,000 | 通知項目方 |
| Limit | ±2% 深度 < $5,000（持續 10 分鐘） | Reduce-only mode |

**低流動性自動調整：**
- 若 CEX 2% 深度 < $10k → 降低 `base_max` 至 $10k
- 若 CEX 2% 深度 < $10k → 降低 `User Max Notional` 至 $50k

### 5.4 價格來源監控

**Standard Listing：**

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 2 個有效來源 | 正常運作 |
| Warning | 來源間偏離 > 3% | 警報 + 人工審核 |
| Limit | 僅剩 1 個有效來源 | 警報 + 密切監控 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

**Permissionless Listing：**

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 1 個有效來源 | 正常運作 |
| Warning | 價格凍結 > 1 分鐘 | 警報 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

**異常價格處置：**
- 價格凍結 > 1 分鐘 → 警報
- 價格與 24h VWAP 偏離 > 50% → 自動暫停交易
- 價格 5 分鐘內變動 > 30% → 暫停新開倉 10 分鐘

### 5.5 Funding Rate 監控

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | Funding Rate 在 Cap/Floor 範圍內 | 正常運作 |
| Warning | 連續 3 個週期達到 Cap 或 Floor | 警報 + 通知項目方 |
| Limit | 連續 6 個週期達到 Cap 或 Floor | 警報 + 人工審核 |

**異常情境：**

| 情境 | 說明 | 處置 |
|------|------|------|
| 長期正 Funding | 連續 24hr Funding > 0.1%/8hr | 檢查價格操縱或流動性問題 |
| 長期負 Funding | 連續 24hr Funding < -0.1%/8hr | 檢查異常空頭壓力 |
| Funding 異常波動 | 單週期 Funding 變化 > 0.5% | 警報 + 檢查價格來源 |

### 5.6 事件分級與處置總覽

| 等級 | 觸發條件 | 處置動作 |
|------|----------|----------|
| Warning | IF < 120% / 流動性 < $10k / Funding 異常 | 通知項目方 |
| Limit | IF < 80% / CEX 下架 / 價格來源不足 | Reduce-only mode |
| Emergency | IF < 50% / 穿倉且 IF 不足 / 0 個價格來源 | Delist + ADL |

---

## 6. 附錄

### 6.1 IMR Factor 計算細節

**公式：**
```pseudo
multiplier = by_imr_threshold(imr)          // default: all 1.0
mc_adjustment = f(log10(market_cap))
target_c = clamp(imr * multiplier * mc_adjustment, min_target_c, max_target_c)

if max_notional_user > 0:
    imr_factor_user = target_c / (max_notional_user ^ 0.8)
else:
    imr_factor_user = 0

imr_factor_user = clamp(imr_factor_user, min_imr_factor, max_imr_factor)
imr_factor_dmm = imr_factor_user * dmm_factor
```

**參數預設：**
- `min_target_c = 0.001`, `max_target_c = 2.0`
- `min_imr_factor = 1e-10`, `max_imr_factor = 1e-3`
- `dmm_factor = 0.6`

**資料來源：** CoinGecko `coins/markets`（取 `market_cap`, `price`, `rank`；FDV 無值時用 `market_cap` 代替）

**mc_adjustment 線性插值表：**

| log10(market_cap) 範圍 | 插值區間 |
|------------------------|---------|
| ≥ 12.0 | (12.0, 5.0) → (12.3, 3.5) |
| 11.5 - 12.0 | (11.5, 7.0) → (12.0, 5.0) |
| 10.8 - 11.5 | (10.8, 12.0) → (11.5, 7.0) |
| 10.0 - 10.8 | (10.0, 4.0) → (10.8, 12.0) |
| 9.0 - 10.0 | (9.0, 3.0) → (10.0, 4.0) |
| 8.0 - 9.0 | (8.0, 2.5) → (9.0, 3.0) |
| 7.0 - 8.0 | (7.0, 2.0) → (8.0, 2.5) |
| < 7.0 | 固定 2.0 |

最終：`mc_adjustment = clamp(mc_adjustment, 0.5, 15.0)`

### 6.2 TODO 清單

| # | 項目 | 位置 | 狀態 |
|---|------|------|------|
| 1 | base_max 市值分級優先順序說明 | 2.3.2 | 待補充 |
| 2 | base_tick 無 CEX 參考時的規則確認 | 2.2 | 待確認 |
| 3 | Unitary Funding Rounding 變數定義 | 2.3.4 | 待補充 |
| 4 | Permissionless MM Requirement 定義 | 3.3 | 待確認 |
