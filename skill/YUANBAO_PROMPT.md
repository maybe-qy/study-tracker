# 超级元宝 — 适配说明

> 本文件说明 study-tracker 在**超级元宝**（区别于豆包工作任务模式）下的适配要点。
> **核心差异**：豆包工作任务模式是自动化沙箱（后台静默执行命令），超级元宝是对话式智能体带内置工具集（每条操作用户可见，工具能力不同）。

---

## 一键部署提示词

把下面这段话发送给超级元宝即可：

```text
帮我部署运行这个项目：https://github.com/maybe-qy/study-tracker

请先阅读 skill/YUANBAO_PROMPT.md 了解适配说明，然后阅读 skill/QUICKSTART.md 了解流程。
按流程引导我完成首次成绩录入。
```

---

## 一、核心差异：豆包工作任务模式 vs 超级元宝

### 1.1 工具能力对比

| 能力 | 豆包工作任务模式 | 超级元宝 |
|------|------------|--------------|
| **Python 执行** | 内置沙箱，可直接运行 python script.py | 有代码执行工具，但环境可能受限，需先确认可用工具 |
| **安装依赖** | 自动 pip install | 需手动确认或引导用户安装 |
| **Git 操作** | 自动 git clone | 可能需引导用户手动下载，或使用代码执行工具 |
| **文件系统** | 沙箱内完整读写 | 通过文件工具读写，路径可能不同 |
| **管道传递** | 不支持（echo \| python） | 通常不支持，需用文件传参 |
| **输出文件** | 沙箱内生成，需输出给用户 | 需通过文件工具或代码块输出给用户 |
| **中间状态** | 用户不可见，后台静默执行 | 每条工具调用用户可见 |

### 1.2 超级元宝内置的常用工具（需要利用，不要绕开）

超级元宝通常有以下内置工具，**不要自己另外实现**：

| 工具类型 | 用途 | 应用场景 |
|---------|------|---------|
| 文件读取 | 读取项目中的代码/配置文件 | 读取 SKILL.md、Python 脚本等 |
| 代码执行 | 运行 Python/Shell 代码 | 运行 record_exam.py、calc_equivalent.py 等 |
| 文件下载/上传 | 用户上传文件或下载生成的文件 | 用户上传 Excel 数据、下载 HTML 报告 |
| 网页搜索 | 搜索信息 | 搜索 GitHub 项目信息 |
| 网页抓取 | 获取网页内容 | 获取 GitHub 项目 README |

### 1.3 适配策略总览

```
豆包工作任务模式：用户说"帮我录入" → AI 自动执行全部命令 → 输出结果
超级元宝：用户说"帮我录入" → AI 引导获取信息 → 用代码执行工具运行脚本 → 输出结果
```

**关键原则**：超级元宝模式下，不要试图让用户手动操作（如"请打开终端运行以下命令"），而是**善用超级元宝自带的代码执行工具**在后台完成。

---

## 二、部署适配（超级元宝 vs 豆包）

### 2.1 豆包是怎么做的（仅供参考）

豆包工作任务模式会自动：`git clone → pip install → python setup_workspace.py`

### 2.2 超级元宝该怎么做

**方式一：代码执行工具可用（推荐）**

超级元宝有代码执行工具时，用该工具按顺序执行：

```bash
# 第1步：GitHub 上获取项目
# 注意：从 GitHub 拉取项目，如果代码执行工具有网络权限
git clone https://github.com/maybe-qy/study-tracker.git

# 第2步：安装依赖
pip install openpyxl jinja2

# 第3步：初始化工作区
cd study-tracker && python3 src/scripts/setup_workspace.py --workspace .
```

**方式二：代码执行工具不支持 git（常见）**

先引导用户下载项目 ZIP 包（提供 GitHub 链接），然后用代码执行工具解压并执行后续步骤。

**方式三：代码执行工具不可用（回退）**

如果超级元宝没有代码执行能力，**不要尝试运行 Python 脚本**。改为：
- 引导用户在本地运行项目
- 提供明确的本地运行指令
- 用户录入成绩后，手动计算等效分

---

## 三、流程适配

### 3.1 成绩录入

**超级元宝做法**：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 成绩录入流程

我把你的分数录入到系统，需要先确认以下信息——

考试信息（必填）
  · 考试名称：________
  · 考试日期：________

各科分数（必填）
  · 语文、数学、英语（原始分）
  · 选考科目（赋分）

划线信息（选填，有则精度更高）
  · 特控线：________
  · 浙大线：________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

直接回复分数即可，比如"语文102，数学128，英语110..."
```

**不要做的事**：
- ❌ 让用户手动复制 JSON 或运行命令
- ❌ 说"请在终端中执行以下命令"
- ✅ 用代码执行工具替用户操作

### 3.2 构造 JSON 并录入

用代码执行工具运行 Python 脚本：

```python
# 1. 构造 JSON 数据
data = {
    "workspace": ".",
    "exam_name": "11月期中",
    "exam_date": "2026-11",
    "exam_type": "期中",
    "grade": "高二",
    "total_score": 576,
    "school_rank": 150,
    "school_total": 600,
    "cn_score": 102,
    "math_score": 128,
    "en_score": 110,
    "sub1_name": "物理", "sub1_raw": 70, "sub1_assigned": 82,
    "sub2_name": "化学", "sub2_raw": 68, "sub2_assigned": 79,
    "sub3_name": "技术", "sub3_raw": 88, "sub3_assigned": 84
}

# 2. 写入临时文件（因为超级元宝通常不支持管道）
import json
with open("/tmp/exam_data.json", "w") as f:
    json.dump(data, f)

# 3. 运行录入脚本
import subprocess
result = subprocess.run(
    ["python3", "src/scripts/record_exam.py", "--json-file", "/tmp/exam_data.json"],
    capture_output=True, text=True, cwd="study-tracker"
)
print(result.stdout)
```

### 3.3 计算等效分

```python
# 在录入脚本的输出中提取 subjects 等数据
calc_input = {
    "workspace": ".",
    # ... 从录入结果中提取
}
with open("/tmp/calc_input.json", "w") as f:
    json.dump(calc_input, f)

result = subprocess.run(
    ["python3", "src/scripts/calc_equivalent.py", "--json-file", "/tmp/calc_input.json"],
    capture_output=True, text=True, cwd="study-tracker"
)
# 输出保存到文件，供下一步使用
with open("/tmp/eq_result.json", "w") as f:
    f.write(result.stdout)
```

### 3.4 保存等效分

```python
result = subprocess.run(
    ["python3", "src/scripts/save_equivalent.py",
     "--json-file", "/tmp/eq_result.json",
     "--workspace", ".",
     "--exam-name", "11月期中",
     "--exam-date", "2026-11"],
    capture_output=True, text=True, cwd="study-tracker"
)
```

### 3.5 生成报告

```python
result = subprocess.run(
    ["python3", "src/scripts/generate_reports.py", "--workspace", "."],
    capture_output=True, text=True, cwd="study-tracker"
)
```

### 3.6 输出报告给用户

如果超级元宝有文件下载功能，直接提供报告文件链接。如果没有，用代码块输出 HTML 内容：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 报告已生成

以下是本次报告清单：
1. 个人总览.html — 等效分、各科拆分、趋势、院校定位（Tab 整合）
2. 单科追踪.html — 各科分数趋势（Tab 整合）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

请告诉我需要查看哪一份，我输出完整内容给你。
```

---

## 四、超级元宝模式下的关键注意事项

### 4.1 代码执行工具的环境

- 每次代码执行可能是独立环境，**路径和变量不持久**
- 推荐将多个步骤写在一个代码块中，或分步骤但显式传递中间文件
- 如果代码执行环境不支持持久化文件系统，需要用文件下载工具获取输出

### 4.2 用户数据的处理

- 超级元宝模式下，用户的数据文件（Excel）需要通过上传工具获取
- 如果用户没有上传数据文件，引导用户直接说分数（超级元宝记录后写 JSON 文件）
- 不要假设文件系统上有历史数据

### 4.3 进度展示

因为超级元宝的每条工具调用用户可见，要在工具调用前先说明要做什么：

```
[部署] 开始从 GitHub 拉取项目...
[部署] 安装依赖...
[录入] 正在将你的成绩写入系统...
[计算] 正在计算等效分并生成报告...
```

### 4.4 错误处理

| 场景 | 处理方式 |
|------|---------|
| 代码执行工具不支持 git clone | 引导用户下载 ZIP 包 |
| pip install 失败 | 检查环境是否有 pip，或改用其他安装方式 |
| 文件路径不对 | 先用文件读取工具确认项目目录结构 |
| 代码执行工具不可用 | 告知用户需要在本地运行，给出明确指令 |

---

## 五、使用场景模板

### 场景1：首次部署 + 录入成绩

```
用户：帮我部署 study-tracker 并录入成绩

AI：[部署] 正在从 GitHub 获取项目...

【如果代码执行工具支持 git】
→ 执行 git clone + pip install + setup_workspace

【如果不支持 git】
→ 提供 GitHub 链接让用户下载 ZIP
→ 用户上传后，用代码执行工具解压并初始化
→ 或直接使用代码执行工具创建项目文件结构

[录入] 请告诉我你的考试成绩——
```

### 场景2：已有项目，补充录入

```
用户：录入这次期末成绩

AI：请告诉我各科分数和考试信息——
```

### 场景3：用户上传了 Excel 数据文件

```
用户上传了成绩总表.xlsx

AI：用文件读取工具读取 Excel →
如果文件格式符合项目规范，直接读取数据 →
执行计算流程 →
输出报告
```

---

## 六、与豆包工作任务模式共享的部分

以下内容与豆包工作任务模式完全一致，无需重复，直接参考对应文件：

- 数据存储结构 → `SKILL.md`
- 置信度分级体系 → `SKILL.md`
- 等效分计算方法 → `references/calculation_methods.md`
- 数据字段定义 → `references/data_schema.md`
- 交互示例 → `references/interaction_examples.md`
- 边界案例 → `references/interaction_scripts.md`
- 通用流程指南 → `QUICKSTART.md`