# 豆包工作任务模式 — 一键部署提示词

> 把下面这段话粘贴到豆包的「任务」标签（绿色沙漏图标），发送即可。
> 豆包会自动从 GitHub 拉取项目、初始化工作区、引导你录入成绩。

---

```text
帮我部署运行这个项目：https://github.com/maybe-qy/study-tracker

然后按以下流程操作：

1. 先阅读 skill/QUICKSTART.md，了解完整流程和规则
2. 运行 src/scripts/setup_workspace.py 初始化工作区（--workspace .）
3. 引导我录入第一次考试成绩

技术说明：
- 所有 Python 脚本在 src/scripts/ 目录下
- 依赖 openpyxl 和 jinja2 已在豆包环境中可用
- 豆包沙箱不支持 shell 管道，脚本支持 --json-file 文件传参
  或直接用 from record_exam import run 导入模块调用
```

---

## 手动模式

如果不使用任务模式，也可以直接在豆包对话中粘贴以下任意方式开始：

**新用户（从零开始）：**

> 帮我克隆 https://github.com/maybe-qy/study-tracker，安装依赖，然后引导我录入成绩。

**已有项目的老用户（补充录入）：**

> 在 study-tracker 项目中帮我录入一次新的考试成绩。
