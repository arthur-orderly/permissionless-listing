# Orderly Perps 上架參數與規則

> 相關文件：[Permissionless Listing PRD](./Permissionless%20Listing%20-%20Chinese.md) | [Frontend Requirements](./Permissionless_Listing_Frontend_Requirements.md) | [Slashing System](./Slashing_System.md)

---

## 1. 參考資源

參考交易所：
- Binance: [交易規則](https://www.binance.com/en/futures/trading-rules/perpetual) | [Funding 歷史](https://www.binance.com/en/futures/funding-history/perpetual/real-time-funding-rate)
- Bybit: [交易參數](https://www.bybit.com/en/announcement-info/transact-parameters) | [Funding Rate](https://www.bybit.com/en/announcement-info/fund-rate/)
- OKX: [永續合約資訊](https://www.okx.com/trade-market/info/swap) | [Funding Swap](https://www.okx.com/trade-market/funding/swap)
- CoinGecko API: [coins/markets](https://api.coingecko.com/api/v3/coins/markets) | [search](https://api.coingecko.com/api/v3/search)

---

## 2. 上架參數指南

| 參數 | Broker可配 | 設定規則 | 警示/備註 |
|:-----|:---------:|:---------|:----------|
| Base_ccy | ✓ | 查詢 CoinGecko 的 API ID | 以 CoinGecko app_id 為準 |
| quote_min | - | 設為 `0` | - |
| quote_max | - | 設為 `100,000` | 例外：BTC 設為 `200,000` |
| quote_tick | ✓ | 參考其他 CEX 合約的 `quote_tick` 僅作為**小數位上限**參考（不要求與 CEX 相同）<br>注意：處理倍數型（如 `1000PEPE`）<br>**若有 CEX 參考：**Broker 自行指定 `quote_tick`，但小數位數不得多於 `min(decimal_cex, decimal_oracle)`，否則 API 拒絕<br>**若無其他 CEX 參考：**Broker 自行指定 `quote_tick`，且小數位數不得多於 `decimal_oracle`，否則 API 拒絕 | 若 `quote_tick / price > 1%` 則警示 |
| base_min | ✓ | 參考其他 CEX<br>確保 `base_min × price` 滿足 `min_notional`（約 10 USDC）<br>**若無其他 CEX 參考：**`base_min = ceil(min_notional / price)`，`min_notional = 10` | 避免極端值 |
| base_max | - | 標準上限：<br>• $3m：BTC, ETH, SOL<br>• $1m：市值前 20<br>• $500k：市值前 100<br><br>市值規則：<br>• < $25m：~$50k **（若 2% 深度 < $10k，降至 $10k）**<br>• $25m - $50m：~$75k<br>• $50m - $75m：~$100k<br>• $75m - $100m：~$125k<br>• > $100m：~$150k | 設定市值追蹤警示（TODO: 優先順序說明） |
| base_tick | ✓ | 參考其他 CEX 合約的 `base_tick`<br>（通常與 `base_min` 相同）<br>**若無其他 CEX 參考：**`base_tick = base_min`（TODO: 規則待確認） | - |
| min_notional | - | 設為 `10` | - |
| price_range | - | 新上架 (TGE)：第一天設 `0.1` (10%)（與 MM 確認後隔天降低）<br>標準：<br>• 20x 槓桿：`3%`<br>• 10x 槓桿：`5%` | - |
| price_scope | - | 設為 `0.6` | - |
| IMR | ✓ | 公式：`1 / max_leverage`<br>新上架 (TGE)：設為 `0.2`（最高 5x）<br>市值 < $30m：建議設 `0.2`（最高 5x）<br>市值 > $30m：依上架團隊規則（最大值 `0.1` / 10x） | - |
| MMR | - | 公式：`IMR / 2`<br>例外：若 `IMR = 0.1` 且市值 < $100m，設 `MMR = 0.06`（而非 0.05） | - |
| Max Notional (DMM) | - | 設為 `1,000,000,000,000`（無限制） | - |
| Max Notional (User) | ✓ | 依市值：<br>• < $25m：~$75k<br>• $25m - $50m：~$100k<br>• $50m - $75m：~$150k<br>• $75m - $100m：~$200k<br>• $100m - $200m：~$250k<br>• $200m - $600m：~$500k<br>• $600m - $1B：~$500k<br>• > $1B：~$1m<br><br>深度檢查：若各 CEX ±2% 深度最大值 < $10k，降至 ~$50k | 設定市值追蹤警示 |
| IMR_Factor | - | 依 IMR Factor 暫行公式計算（見 2.1.3.1） | - |
| Funding Period | - | 查詢 Funding 間隔。優先順序：Binance > OKX > Bybit | - |
| Funding Cron | - | `CEX 間隔小時數 × 3600`<br>• 1h：`3600`（`0 0 * * * ?`）<br>• 4h：`0 0 0,4,8,12,16,20 * * ?`<br>• 8h：`0 0 0,8,16 * * ?` | - |
| Funding Cap | - | `主要 CEX Funding Cap × (Orderly 週期 / CEX 週期)`<br>優先順序：Binance > Bybit > OKX<br>備用：若僅在二線 CEX 上架，設為 `4%`（例：`2% × (8/4) = 4%`） | - |
| Funding Floor | - | `主要 CEX Funding Floor × (Orderly 週期 / CEX 週期)` | - |
| Interest Rate | - | 與 CEX 相同（標準 `0.01%`）<br>注意：固定使用 8h/0.01%，程式會處理其他週期的轉換 | - |
| Cap/Floor Interest | - | `(Orderly 週期 / CEX 週期) × 0.01%`（Floor 為負值） | - |
| Mark Price Max Dev | - | `Roundup(5.25% / Orderly Funding Cap, 3)`<br>範例：`5.25% / 4%` = 1.3125 → `1.313` | - |
| Unitary Funding Rounding | - | 邏輯：`min_funding_rate ≤ 10^-5`<br>設定：`config_suf ≥ min(10^-6, min_funding_rate)`<br>參考 [Tech] Funding Rounding Scale 表格（TODO: 變數定義） | - |
| Slope Parameters | - | • `Slope1`: 1<br>• `Slope2`: 2<br>• `Slope3`: 4<br>• `p1`: 0.5%<br>• `p2`: 1.5% | - |
| impact_margin_notional | - | • 槓桿 > 10x：`1000`<br>• 5x < 槓桿 ≤ 10x：`500`<br>• 槓桿 ≤ 5x：`100`<br>• 熱門 TGE（>1B 市值, 5x）：`500` | - |
| std_liquidation_fee | - | • 槓桿 ≤ 10x：`2.4%`<br>• 槓桿 ≥ 20x：`1.5%`<br>• 槓桿 ≥ 50x：`0.8%` | - |
| liquidator_fee | - | `std_liquidation_fee / 2` | - |
| claim_insurance_fund_discount | - | • 槓桿 ≤ 10x：`1%`<br>• 槓桿 ≥ 20x：`0.75%`<br>• 槓桿 ≥ 50x：`0.4%` | - |
| Index Price Weights | - | 查詢 CoinGecko 現貨交易量（最多 7 個來源）<br>`Weight(CEX1) = Volume(CEX1) / Sum(Volumes)` | - |
| Index Source (Supported) | ✓ | BINANCE, HUOBI, OKX, GATEIO, BYBIT, KUCOIN, COINBASE, MEXC, BITGET, BINGX, HYPERLIQUID, WOOX, LBANK<br>ORACLE: PYTH, STORK | - |
| bbo valid interval | - | • Binance/Bybit/OKX：`10`<br>• MEXC/Gate：`20`<br>• 其他：`30` | - |
| trade valid interval | - | 設為 `7,200` | - |
| Index quote_tick | - | 與 Symbol 的 `quote_tick` 相同 | - |
| Price (Input) | - | Symbol 的現貨價格 | - |

### 2.1 規則補充（程式化）

**2.1.1 價格與下單參數**

```pseudo
base_ccy = coingecko.id(app_id)
base_symbol = coingecko.symbol(app_id)
if cex_spot_symbol exists and cex_spot_symbol != base_symbol:
    warn("spot symbol mismatch")

quote_min = 0
quote_max = (symbol == "BTC" ? 200000 : 100000)

price_decimals = decimals(oracle_price)
if cex_quote_tick exists:
    max_decimals = min(decimals(cex_quote_tick), price_decimals)
else:
    max_decimals = price_decimals
assert decimals(broker_quote_tick) ≤ max_decimals     // 否則 API 拒絕
if broker_quote_tick / oracle_price > 0.01:
    warn("quote_tick / price > 1%")

min_notional = 10
if cex_base_min exists:
    base_min = cex_base_min
else:
    base_min = ceil(min_notional / oracle_price)
assert base_min * oracle_price ≥ min_notional         // 否則 API 拒絕

if cex_base_tick exists:
    base_tick = cex_base_tick
else:
    base_tick = base_min

if is_TGE_day1:
    price_range = 0.1
else:
    price_range = listing_team_rule(max_leverage)      // 20x -> 0.03; 10x -> 0.05
price_scope = 0.6
```

**2.1.2 Notional 與限額**

```pseudo
market_cap_rank = coingecko.market_cap_rank

base_max =
    symbol in {BTC, ETH, SOL} ? 3000000 :
    market_cap_rank ≤ 20 ? 1000000 :
    market_cap_rank ≤ 100 ? 500000 :
    by_market_cap_tier()                               // 見表格對應值（TODO: 表格補充優先順序說明）
if depth_2pct < 10000:
    base_max = 10000

global_max_oi = by_market_cap_tier()                   // 見 4.7，依市值規則
user_max_notional = by_market_cap_tier()               // 見表格對應值
if price_sources == 1:
    global_max_oi = global_max_oi * 0.5
    user_max_notional = user_max_notional * 0.5
if depth_2pct < 10000:
    user_max_notional = 50000

dmm_max_notional = 1000000000000
```

**2.1.3 槓桿與保證金**

```pseudo
if price_sources == 1:
    max_leverage = min(max_leverage, 5)

if is_TGE or market_cap < 30000000:
    imr = 0.2
else:
    imr = min(1 / max_leverage, 0.1)

mmr = imr / 2
if imr == 0.1 and market_cap < 100000000:
    mmr = 0.06

impact_margin_notional =
    (is_TGE and market_cap > 1000000000 and max_leverage ≤ 5) ? 500 :
    max_leverage > 10 ? 1000 :
    max_leverage > 5  ? 500  :
    100
```

**2.1.3.1 IMR Factor（暫行公式）**

資料來源（CoinGecko）：
- 以 `coins/markets` 取得 `market_cap`, `price`, `rank`（FDV 無值時可用 `market_cap` 代替）

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

參數預設：
- `min_target_c = 0.001`, `max_target_c = 2.0`
- `min_imr_factor = 1e-10`, `max_imr_factor = 1e-3`
- `dmm_factor = 0.6`

`mc_adjustment = f(log10(market_cap))`（線性插值）：
- log_mc ≥ 12.0：介於 (12.0, 5.0) 與 (12.3, 3.5)
- 11.5 ≤ log_mc < 12.0：介於 (11.5, 7.0) 與 (12.0, 5.0)
- 10.8 ≤ log_mc < 11.5：介於 (10.8, 12.0) 與 (11.5, 7.0)
- 10.0 ≤ log_mc < 10.8：介於 (10.0, 4.0) 與 (10.8, 12.0)
- 9.0 ≤ log_mc < 10.0：介於 (9.0, 3.0) 與 (10.0, 4.0)
- 8.0 ≤ log_mc < 9.0：介於 (8.0, 2.5) 與 (9.0, 3.0)
- 7.0 ≤ log_mc < 8.0：介於 (7.0, 2.0) 與 (8.0, 2.5)
- log_mc < 7.0：固定 2.0

最終：`mc_adjustment = clamp(mc_adjustment, 0.5, 15.0)`

**2.1.4 Funding 與利率**

```pseudo
funding_period = cex_period(priority = Binance > OKX > Bybit)
funding_cron = funding_period_hours * 3600

funding_cap = cex_cap * (orderly_period / cex_period)
if only_tier2_cex:
    funding_cap = 0.04
funding_floor = cex_floor * (orderly_period / cex_period)

interest_rate = cex_interest_rate                     // default 0.01% per 8h
cap_floor_interest = (orderly_period / cex_period) * 0.01%

mark_price_max_dev = roundup(0.0525 / funding_cap, 3)

unitary_funding_rounding:
    config_suf ≥ min(1e-6, min_funding_rate)

slope_parameters:
    slope1 = 1; slope2 = 2; slope3 = 4
    p1 = 0.005; p2 = 0.015
```

**2.1.5 清算費率**

```pseudo
std_liquidation_fee =
    max_leverage ≤ 10 ? 0.024 :
    max_leverage ≥ 50 ? 0.008 :
    max_leverage ≥ 20 ? 0.015 : 0.024

liquidator_fee = std_liquidation_fee / 2
claim_insurance_fund_discount =
    max_leverage ≥ 50 ? 0.004 :
    max_leverage ≥ 20 ? 0.0075 :
    0.01
```

**2.1.6 指數與行情**

```pseudo
index_price_weight = volume_i / sum(volumes)
bbo_valid_interval = by_exchange()                     // Binance/Bybit/OKX=10; MEXC/Gate=20; others=30
trade_valid_interval = 7200
index_quote_tick = quote_tick
```

---

## 3. 上架要求

### 3.1 價格來源要求

| 上架類型 | 最少來源數 | 建議來源 |
|---------|-----------|---------|
| 標準上架 (Standard) | 3 | Binance, Bybit, OKX, MEXC, Gate, Pyth, Stork |
| 無許可上架 (Permissionless) | 1 | 同上，但允許單一來源 |

**備註：**
- 若來源數 > 3 但交易量極低且 CoinGecko 有紅旗警告，則忽略該來源
- Permissionless Listing 僅需 1 個價格來源，但建議盡可能提供多個來源以降低價格操縱風險
- 價格來源數較少時，需同步收緊槓桿與名目限額，並影響 IF 最低需求（見 2.1.2、2.1.3、4.1、4.7）

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
IF Balance ≥ Σ (Global Max OI_adjusted of Symbol_i × IF Rate_i)
```

其中 `Global Max OI_adjusted` 需先套用價格來源數的調整（見 2.1.2 / 4.7），`Σ (Global Max OI_adjusted × IF Rate)` 為 **最低 IF 要求（min_IF）**。下方所有門檻百分比均以 `min_IF` 為基準。

#### IF 餘額狀態與系統動作

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 120% min_IF | 正常運作 |
| Warning | < 120% min_IF | 通知項目方補充 IF |
| Limit | < 80% min_IF | Reduce-only mode（僅允許減倉） |
| Emergency | < 50% min_IF | Emergency Delist |

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
Liq Balance ≥ Max(
    Global Max OI × Liq Rate,
    User Max Notional × IMR × Concurrent Factor
)
```

#### Liq 餘額狀態與系統動作

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 120% min | 正常運作 |
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
MM Balance ≥ (Global Max OI × MM Rate) + Buffer
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
| Normal | ≥ 100% min | 正常運作 |
| Warning | < 100% min | 通知項目方補充 |
| Limit | < 50% min（持續 30 分鐘） | Reduce-only mode |

> **備註**：Standard Listing 由平台 MM 負責，不需監控；Permissionless 由項目方自行做市，需監控餘額

---

### 4.4 流動性深度要求

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ±2% 深度 ≥ $10,000 | 正常交易 |
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
| Normal | ≥ 2 個有效來源 | 正常運作 |
| Warning | 來源間偏離 > 3% | 警報 + 人工審核 |
| Limit | 僅剩 1 個有效來源 | 警報 + 密切監控 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

#### 無許可上架 (Permissionless Listing)

| 狀態 | 門檻 | 系統動作 |
|------|------|---------|
| Normal | ≥ 1 個有效來源 | 正常運作 |
| Warning | 價格凍結 > 1 分鐘 | 警報 |
| Emergency | 0 個有效來源 | 立即暫停交易 |

**單一價格來源的額外限制（Permissionless）：**

| 限制項目 | 多來源 (≥2) | 單一來源 (=1) |
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
| Standard | ≥ 3 | 依市值規則 100% | 依市值規則 100% |
| Permissionless | ≥ 2 | 依市值規則 100% | 依市值規則 100% |
| Permissionless | = 1 | 依市值規則 **50%** | 依市值規則 **50%** |

---

### 4.8 上架前驗證清單

| 檢查項目 | 驗證方式 | 失敗處置 |
|---------|---------|---------|
| CoinGecko ID | API 查詢 | 拒絕上架 |
| 黑名單檢查 | 內部資料庫 | 拒絕上架 |
| IF 餘額 | ≥ 最低要求 | 拒絕上架 |
| Liq 餘額 | ≥ 最低要求 | 拒絕上架 |
| MM 餘額 | ≥ 最低要求 | 拒絕上架 |
| 價格來源 | ≥ 1 個有效來源（Permissionless） | 拒絕上架 |

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


# 6. 附錄：PRD 摘錄（Post-listing Risk Control）

## 6.1 監控項目

| 監控項 | 檢查內容 | 檢查頻率 |
|--------|----------|----------|
| 價格來源狀態 | 來源是否可用、更新頻率 | 同當前檢查頻率 |
| 流動性深度 | ±2% 深度是否 ≥ $10,000 | 每 1 分鐘 |
| 清算頻率 | 每小時清算次數是否異常 | 每 1 小時 |
| IF Account | 餘額是否 ≥ 最低要求 | 每 1 分鐘 |
| Liquidation Account | 餘額是否 ≥ 最低要求 | 每 1 分鐘 |

---

## 6.2 事件分級與處置

| 等級 | 觸發條件 | 處置動作 |
|------|----------|----------|
| Warning | IF < 120% min_balance | 通知項目方 |
| Warning | 流動性深度 < $10,000 | 通知項目方 |
| Limit | IF < 80% min_balance | Reduce-only mode |
| Limit | CEX 下架 / 價格來源 < 1 | Reduce-only mode |
| Emergency | IF < 50% min_balance | Delist |
| Emergency | 穿倉且 IF 不足 | Delist + ADL |

### IF 餘額狀態與系統動作

| IF 狀態 | 系統動作 |
|---------|----------|
| < 120% min_IF | 通知項目方補充 IF |
| < 80% min_IF | Reduce-only mode（僅允許減倉） |
| < 50% min_IF | Emergency Delist |
