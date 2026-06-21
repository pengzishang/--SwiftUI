# 接口文档 B：《日报阅读器》v1.0

## 0. 说明

当前仓库没有 SwiftUI 源码、网络层或模型文件，本接口文档基于 `docs/v1.0/01-product-requirements.md`、当前接口可用性核验，以及知乎日报候选接口的实际返回形态整理。

核验日期：2026-06-21。

注意：

- 这是候选非官方接口，不是稳定开放契约；
- `GET /api/4/news/latest` 当前可返回 200；
- `HEAD /api/4/news/latest` 当前返回 405，因此健康检查不要用 HEAD；
- 外部接口可能随时变更、限流、403、502 或下线；
- 客户端必须有缓存与错误态兜底。

## 1. 基础信息

| 项 | 内容 |
| --- | --- |
| 基础域名 | `https://news-at.zhihu.com` |
| API Base URL | `https://news-at.zhihu.com/api/4` |
| 数据格式 | JSON |
| 鉴权 | 无需登录、无 token |
| 主要方法 | `GET` |
| 字符编码 | `application/json; charset=UTF-8` |
| 项目定位 | 学习作品集，非知乎官方产品 |
| 稳定性 | 非官方契约，必须按不稳定处理 |

推荐客户端策略：

| 项 | 建议 |
| --- | --- |
| 超时 | 10-15 秒 |
| 缓存 | URLCache 可用，但必须有应用层缓存 |
| 解码 | 容错解析，缺字段不崩溃 |
| 重试 | 用户触发重试优先，避免自动频繁重试 |
| 健康检查 | 用 GET，不用 HEAD |

## 2. 接口清单

| 场景 | 方法 | 路径 | 用途 |
| --- | --- | --- | --- |
| 获取今日日报 | `GET` | `/news/latest` | 首页首次加载、下拉刷新 |
| 获取历史日报 | `GET` | `/news/before/{date}` | 向前分页加载历史列表 |
| 获取文章详情 | `GET` | `/news/{id}` | 文章详情页阅读与分享 |

完整 URL：

```text
GET https://news-at.zhihu.com/api/4/news/latest
GET https://news-at.zhihu.com/api/4/news/before/20260621
GET https://news-at.zhihu.com/api/4/news/9790569
```

## 3. 通用约定

### 3.1 日期

| 字段/参数 | 格式 | 示例 | 说明 |
| --- | --- | --- | --- |
| `date` | `yyyyMMdd` | `20260621` | 无分隔符日期字符串 |

历史接口 `/news/before/{date}` 的语义是“获取指定日期之前的一天日报”，不是获取指定日期当天。

示例：

```text
GET /news/before/20260621
```

预期返回日期通常是：

```json
{
  "date": "20260620"
}
```

### 3.2 ID

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Int | 文章唯一 ID，用于 `/news/{id}` |

iOS 模型建议使用 `Int` 或 `Int64`。

### 3.3 容错原则

- 图片字段允许为空、缺失、失效；
- `body` 允许为空字符串或缺失；
- `share_url` 允许缺失；
- `stories`、`top_stories` 允许为空数组；
- 未识别字段忽略；
- 非关键字段类型异常不能导致 App 崩溃；
- 必要字段缺失时，该条内容应降级或不展示为可点击项。

## 4. 获取今日日报

### 请求

```http
GET /news/latest
```

### 请求参数

无。

### 成功响应结构

```json
{
  "date": "20260621",
  "stories": [],
  "top_stories": []
}
```

### 字段

| 字段 | 类型 | 必要性 | 说明 |
| --- | --- | --- | --- |
| `date` | String | 建议必有 | 当前日报日期 |
| `stories` | `[StorySummary]` | 建议必有 | 普通日报列表 |
| `top_stories` | `[TopStory]` | 可选 | 顶部故事列表 |

`StorySummary`：

| 字段 | 类型 | 必要性 | 说明 |
| --- | --- | --- | --- |
| `id` | Int | 必要 | 文章 ID |
| `title` | String | 必要 | 文章标题 |
| `images` | `[String]` | 可选 | 列表缩略图，通常取第一个 |
| `hint` | String | 可选 | 来源/阅读时长等提示 |
| `url` | String | 可选 | 文章 URL，可作分享兜底 |
| `type` | Int | 可选 | 内容类型，v1.0 不做业务分支 |
| `ga_prefix` | String | 可选 | 统计字段，v1.0 忽略 |
| `image_hue` | String | 可选 | 图片色彩信息，v1.0 忽略 |

`TopStory`：

| 字段 | 类型 | 必要性 | 说明 |
| --- | --- | --- | --- |
| `id` | Int | 必要 | 文章 ID |
| `title` | String | 必要 | 顶部故事标题 |
| `image` | String | 可选 | 顶部大图 |
| `url` | String | 可选 | 文章 URL |
| `type` | Int | 可选 | 内容类型 |
| `ga_prefix` | String | 可选 | 统计字段，v1.0 忽略 |
| `image_hue` | String | 可选 | 图片色彩信息，v1.0 忽略 |

### 客户端处理

- `top_stories` 为空：隐藏顶部故事区；
- `stories` 为空：展示空态；
- `title` 缺失或为空：该条不展示为正常可点击文章；
- `images` 为空或加载失败：展示占位或纯文本卡片；
- 刷新失败：保留旧内容并提示“刷新失败，已保留上次内容”。

## 5. 获取历史日报

### 请求

```http
GET /news/before/{date}
```

### 路径参数

| 参数 | 类型 | 必要性 | 示例 | 说明 |
| --- | --- | --- | --- | --- |
| `date` | String | 必要 | `20260621` | 请求该日期之前的一天日报 |

### 成功响应

```json
{
  "date": "20260620",
  "stories": []
}
```

### 字段

| 字段 | 类型 | 必要性 | 说明 |
| --- | --- | --- | --- |
| `date` | String | 建议必有 | 实际返回的日报日期 |
| `stories` | `[StorySummary]` | 建议必有 | 该日期下的普通日报列表 |

历史接口不返回 `top_stories`。

### 分页规则

```text
1. 首次请求 /news/latest
2. 读取 latest.date，例如 20260621
3. 加载更多：GET /news/before/20260621
4. 响应 date = 20260620
5. 下一次加载更多：GET /news/before/20260620
```

客户端状态建议：

| 状态 | 字段 |
| --- | --- |
| 当前最早日期 | `oldestLoadedDate` |
| 是否正在加载 | `isLoadingMore` |
| 是否还有更多 | 接口无明确 `hasMore`，空列表不等于永久无更多 |
| 去重依据 | `story.id` |

## 6. 获取文章详情

### 请求

```http
GET /news/{id}
```

### 路径参数

| 参数 | 类型 | 必要性 | 示例 | 说明 |
| --- | --- | --- | --- | --- |
| `id` | Int | 必要 | `9790569` | 文章 ID |

### 成功响应结构

```json
{
  "id": 9790569,
  "title": "文章标题",
  "body": "<div class=\"main-wrap content-wrap\">...</div>",
  "image": "https://example.com/image.jpg",
  "images": ["https://example.com/thumb.jpg"],
  "share_url": "http://daily.zhihu.com/story/9790569",
  "url": "https://daily.zhihu.com/story/9790569",
  "css": ["http://news-at.zhihu.com/css/news_qa.auto.css"],
  "js": [],
  "type": 0,
  "ga_prefix": "062107",
  "image_hue": "0x7d8fb3"
}
```

### 字段

| 字段 | 类型 | 必要性 | 说明 |
| --- | --- | --- | --- |
| `id` | Int | 必要 | 文章 ID |
| `title` | String | 建议必有 | 文章标题 |
| `body` | String | 可选 | HTML 正文片段 |
| `image` | String | 可选 | 详情头图 |
| `images` | `[String]` | 可选 | 图片数组 |
| `share_url` | String | 可选 | 分享链接，优先使用 |
| `url` | String | 可选 | 文章 URL，分享兜底 |
| `css` | `[String]` | 可选 | 正文样式 CSS |
| `js` | `[String]` | 可选 | v1.0 建议忽略 |
| `type` | Int | 可选 | 内容类型 |
| `ga_prefix` | String | 可选 | v1.0 忽略 |
| `image_hue` | String | 可选 | v1.0 忽略 |

### HTML 渲染

接口返回的是 HTML 片段，可包装成完整 HTML：

```html
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="{css[0]}">
</head>
<body>
  {body}
</body>
</html>
```

处理规则：

- `body` 为空：展示“文章内容暂不可用”；
- CSS 加载失败：仍尝试展示正文；
- JS 默认不执行；
- 外链打开行为要可控，不能破坏 App 返回路径；
- 深色模式下至少保证详情页外壳可读。

## 7. 分享规则

分享链接优先级：

1. `detail.share_url`
2. `detail.url`
3. `summary.url`
4. 都没有：禁用分享或提示“当前文章暂不可分享”

分享内容建议：

```text
{title}
{url}
```

## 8. 错误处理

| 类型 | 示例 | 处理 |
| --- | --- | --- |
| 网络错误 | 断网、DNS 失败、TLS 失败 | 读缓存；无缓存显示错误态 |
| 超时 | 超过 10-15 秒 | 读缓存；提示重试 |
| 非 2xx | 403、404、500、502 | 不解析为成功；读缓存 |
| 空 body | 404 body 为空 | 视为失败 |
| JSON 解析失败 | 字段类型变化 | 读缓存；无缓存错误态 |
| 业务空数据 | `stories: []` | 按空态处理，不一定是错误 |

推荐 UI 文案：

| 场景 | 文案 |
| --- | --- |
| 首页无网络无缓存 | 网络不可用，请检查连接后重试 |
| 首页刷新失败但有旧内容 | 刷新失败，已保留上次内容 |
| 首页离线缓存 | 当前离线，正在显示缓存内容 |
| 历史加载失败 | 加载历史日报失败，请重试 |
| 详情无网络无缓存 | 文章加载失败，请检查网络后重试 |
| 详情缓存 | 正在显示缓存内容 |
| 正文为空 | 文章内容暂不可用 |
| 分享链接缺失 | 当前文章暂不可分享 |

## 9. 缓存策略

### 9.1 列表缓存

| 项 | 建议 |
| --- | --- |
| 缓存键 | `daily.latest`、`daily.list.{yyyyMMdd}` |
| 范围 | 最近 30 天 |
| 写入 | 网络请求成功且解析成功后 |
| 读取 | 首屏失败、刷新失败、离线启动 |
| 损坏处理 | 删除或忽略损坏缓存，不崩溃 |

### 9.2 详情缓存

| 项 | 建议 |
| --- | --- |
| 缓存键 | `daily.detail.{id}` |
| 范围 | 用户打开过的文章详情 |
| 写入 | 详情请求成功且解析成功后 |
| 读取 | 详情请求失败、离线 |
| 正文为空 | 不建议覆盖已有非空缓存 |

## 10. 推荐 Swift 模型

```swift
struct LatestResponse: Decodable {
    let date: String?
    let stories: [StorySummary]?
    let topStories: [TopStory]?

    enum CodingKeys: String, CodingKey {
        case date
        case stories
        case topStories = "top_stories"
    }
}

struct HistoryResponse: Decodable {
    let date: String?
    let stories: [StorySummary]?
}

struct StorySummary: Decodable, Identifiable {
    let id: Int
    let title: String?
    let images: [String]?
    let hint: String?
    let url: String?
    let type: Int?
    let gaPrefix: String?
    let imageHue: String?

    enum CodingKeys: String, CodingKey {
        case id, title, images, hint, url, type
        case gaPrefix = "ga_prefix"
        case imageHue = "image_hue"
    }
}

struct TopStory: Decodable, Identifiable {
    let id: Int
    let title: String?
    let image: String?
    let url: String?
    let type: Int?
    let gaPrefix: String?
    let imageHue: String?

    enum CodingKeys: String, CodingKey {
        case id, title, image, url, type
        case gaPrefix = "ga_prefix"
        case imageHue = "image_hue"
    }
}

struct ArticleDetail: Decodable, Identifiable {
    let id: Int
    let title: String?
    let body: String?
    let image: String?
    let images: [String]?
    let shareURL: String?
    let url: String?
    let css: [String]?
    let js: [String]?
    let type: Int?
    let gaPrefix: String?
    let imageHue: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, image, images, url, css, js, type
        case shareURL = "share_url"
        case gaPrefix = "ga_prefix"
        case imageHue = "image_hue"
    }
}
```

## 11. Mock 服务约定

后端或本地 mock 服务建议实现同路径：

```text
GET /api/4/news/latest
GET /api/4/news/before/{date}
GET /api/4/news/{id}
```

必备 mock 场景：

| 场景 | 返回 |
| --- | --- |
| 正常 latest | `date + stories + top_stories` |
| 无顶部故事 | `top_stories: []` |
| 无普通列表 | `stories: []` |
| 历史分页 | `/before/{date}` 返回前一天 `date` |
| 详情正常 | `title + body + share_url` |
| 详情无正文 | `body: ""` 或缺失 |
| 缺图片 | 移除 `images` / `image` |
| 缺分享链接 | 移除 `share_url` 和 `url` |
| 404 | HTTP 404 + 空 body |
| 5xx | HTTP 500 |
| 慢请求 | 延迟 10 秒以上 |
| 解析异常 | 字段类型错误 |

## 12. 推断项

以下为实现建议，不是当前仓库代码事实：

- Swift 网络层命名；
- 缓存键设计；
- 超时时间；
- HTML 包装方式；
- mock 服务错误场景；
- 图片缓存由 `URLCache`、`AsyncImage` 或图片库处理。
