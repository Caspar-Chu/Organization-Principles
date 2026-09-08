# ex1（不考虑数据相关）五级流水 CPU — soc_bram 仿真验证步骤总结

> 本文档总结本次在 **Windows + Vivado 2018.3** 环境下，对 LoongArch 五级流水 `myCPU`（第一章 / ex1）完成 Behavioral Simulation 并得到 `----PASS!!!` 的完整流程。  
> 开发可在 Mac 上进行，仿真与验收在 Windows 上完成。

---

## 1. 验证目标与通过标准

| 项目 | 说明 |
|------|------|
| 实验内容 | 单发射五级流水（IF / ID / EXE / MEM / WB），**暂不处理**寄存器相关冲突 |
| 测试镜像 | `for_test_obj/ex1_obj/` |
| 仿真工程 | `mycpu_env/soc_verify/soc_bram` |
| 仿真方式 | **Behavioral Simulation**（行为级仿真） |
| 通过标志 | Tcl Console / 仿真日志出现 **`----PASS!!!`** |

说明：

- 测试台会把 CPU 的 `debug_wb_*` 写回轨迹与 `golden_trace.txt` 逐条对比。
- 对比失败会打印 `Error!!!`（含 reference / mycpu 的 PC、写寄存器号、写数据），并 `$finish`。
- 全部比对通过且功能测试点结束，打印 `Test end!` 与 `----PASS!!!`。

---

## 2. 目录与关键路径（以本次 Windows 工程为例）

以下路径按本次实际使用的 Windows 路径书写；若你的盘符/用户名不同，请整体替换。

```text
Organization-Principles/
├── for_test_obj/
│   └── ex1_obj/                    # ex1 指令/数据 RAM 初始化文件
│       ├── inst_ram.mif / .coe
│       └── data_ram.mif / .coe
└── cdp_ede_local-master/
    └── mycpu_env/
        ├── myCPU/                  # ★ 你的 CPU RTL（必改、必同步）
        │   ├── mycpu_top.v
        │   ├── mycpu_head.v
        │   ├── IF_stage.v … WB_stage.v
        │   ├── alu.v / regfile.v / tools.v
        │   └── ...
        ├── func/obj/               # ★ 仿真时 $readmemb 读取的 mif（需拷贝 ex1）
        │   ├── inst_ram.mif
        │   └── data_ram.mif
        ├── gettrace/
        │   └── golden_trace.txt    # ★ 写回轨迹金标准
        └── soc_verify/soc_bram/
            ├── testbench/
            │   ├── mycpu_tb.v      # 对比 golden_trace
            │   └── sync_ram.v      # 加载 inst/data mif
            └── run_vivado/
                ├── create_project.tcl
                └── project/
                    └── loongson.xpr
```

本次 Windows 根路径示例：

```text
C:/Users/Administrator/Desktop/LA/Organization-Principles/
```

---

## 3. 环境约定

### 3.1 软硬件分工

| 机器 | 职责 |
|------|------|
| Mac（或任意编辑机） | 编写 / 修改 `myCPU` RTL，用 git 版本管理 |
| Windows | 安装 Vivado，建工程、跑仿真、看波形与 PASS |

推荐流程：

```text
Mac 改代码 → git push → Windows git pull → Vivado 重新仿真
```

也可用 U 盘 / 网盘整目录同步 `mycpu_env/myCPU/`（至少同步该目录）。

### 3.2 Vivado 版本注意

- 本次使用 **Vivado 2018.3**。
- 工程内部分 IP（如 `clk_pll`）可能来自更高版本，**综合（Synthesis）可能报 IP lock / 版本不匹配**。
- **ex1 功能验收只需 Behavioral Simulation**，不要先做 Synthesis / Implementation。

### 3.3 不需要选 Board

创建 `soc_bram` 工程时**不必**在起始页选开发板；用官方 `create_project.tcl` 即可。

---

## 4. 验证前准备（一次性 / 换测试时）

### 4.1 确认 CPU 源文件齐全

`mycpu_env/myCPU/` 下至少应有：

- `mycpu_top.v`、`mycpu_head.v`
- `IF_stage.v`、`ID_stage.v`、`EXE_stage.v`、`MEM_stage.v`、`WB_stage.v`
- `alu.v`、`regfile.v`、`tools.v`

接口要求（第一章）：

- 有 `inst_sram_en` / `data_sram_en`
- `inst_sram_we` / `data_sram_we` 为 **4 bit** 字节写使能

Windows 侧每次更新代码后，确认 Vivado 工程已包含这些文件（新建 `.v` 时需 Add Sources，或重新 `source create_project.tcl`）。

### 4.2 拷贝 ex1 测试镜像到 `func/obj`

仿真里 `sync_ram.v` 通过 `$readmemb` 加载：

```text
.../mycpu_env/func/obj/inst_ram.mif
.../mycpu_env/func/obj/data_ram.mif
```

操作步骤：

1. 若没有目录则新建：`mycpu_env/func/obj/`
2. 从 `for_test_obj/ex1_obj/` **复制并覆盖**：
   - `inst_ram.mif`、`data_ram.mif`
   - （建议一并）`inst_ram.coe`、`data_ram.coe`
3. 目标路径示例：

```text
C:\Users\Administrator\Desktop\LA\Organization-Principles\cdp_ede_local-master\mycpu_env\func\obj\
```

**常见故障：** 未拷贝或路径不对 → 指令 RAM 为空 → `debug_wb_pc` 卡在 `0x1c000000`，写回信号长期为 `X`。

### 4.3 准备 `golden_trace.txt`

对比参考轨迹来自：

```text
mycpu_env/gettrace/golden_trace.txt
```

生成方式（首次或换测试程序后）：

1. 用 `mycpu_env/gettrace` 工程按说明跑仿真，得到 `golden_trace.txt`
2. 若文件生成在 `gettrace.sim/...` 深层目录，**复制**到 `gettrace/` 工程旁或测试台打开的路径
3. 确认 `mycpu_tb.v` 中 `TRACE_REF_FILE` 指向该文件

### 4.4 Windows 下相对路径问题（重要）

在 Windows 上，从 Vivado 仿真工作目录出发，相对路径 `$fopen` / `$readmemb` 经常失败。本次做法是改为**绝对路径**，例如：

- `mycpu_tb.v` 中：`TRACE_REF_FILE` → `.../gettrace/golden_trace.txt`
- `sync_ram.v` 中：`inst_ram.mif` / `data_ram.mif` → `.../func/obj/*.mif`

若换电脑，必须改成你本机真实绝对路径，否则会出现打不开 trace / 读不到 mif。

---

## 5. 创建 / 打开 Vivado 工程

### 5.1 用 Tcl 创建工程（首次）

1. 打开 **Vivado**
2. 在底部 **Tcl Console** 分步执行（不要把 `cd` 和 `source` 写成一行错误格式）：

```tcl
cd {C:/Users/Administrator/Desktop/LA/Organization-Principles/cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/run_vivado}
```

```tcl
pwd
```

确认当前目录正确后：

```tcl
source ./create_project.tcl
```

3. 成功后生成：

```text
.../run_vivado/project/loongson.xpr
```

### 5.2 再次打开工程

- 起始页 **Recent Projects** 点 `loongson`，或  
- **Open Project** 选择上面的 `loongson.xpr`

### 5.3 检查 Sources

- **Design Sources**：应能看到 `mycpu_top` 及五级流水子模块  
- **Simulation Sources**：顶层应为 `tb_top`（`mycpu_tb.v`）  
- 不要把 `.mif/.coe` 当成普通 Design Source 乱加；初始化靠 `func/obj` + `$readmemb`（或工程已配置好的路径）

---

## 6. 运行行为级仿真（验收主流程）

### 6.1 启动仿真

1. 左侧 **Flow Navigator**  
2. **Simulation → Run Simulation → Run Behavioral Simulation**  
3. 等待编译 / elaborating / 生成 snapshot（日志中出现 `Built simulation snapshot ...` 表示可跑）

说明：

- 大量 `doesn't have a timescale` 的 WARNING 一般可忽略  
- 若改过 RTL，应 **重新 Launch** 仿真，不要只 Continuously Run 旧 snapshot

### 6.2 跑完整测试

仿真刚启动时时间很短（如 1 µs），程序未跑完，不会出现 PASS。

1. 工具栏点击 **Run All**（全速跑到 `$finish`）  
2. 或设置足够长的 Run for 时间  

本次成功时日志末尾类似：

```text
==============================================================
Test end!
----PASS!!!
$finish called at time : 2060335 ns : File ".../mycpu_tb.v" Line 270
```

### 6.3 在哪里看结果

- 看窗口下方 **Tcl Console** / 仿真 **Log 文字**，不是在波形里找 “PASS” 字样  
- 成功关键字：`----PASS!!!`  
- 失败关键字：`Error!!!`，并打印 reference / mycpu 的 PC、`wb_rf_wnum`、`wb_rf_wdata`

### 6.4 波形辅助观察（可选）

| 信号 | 正常表现 |
|------|----------|
| `debug_wb_pc` | 随程序推进变化，不长期卡在 `0x1c000000` |
| `debug_wb_rf_we / wnum / wdata` | 有写回时为确定数值（非长期全 `X`） |
| `inst_sram_rdata` / `fs_inst` | 加载正确后为具体指令，而非长期 `X` |

仿真初期短暂出现 `X` 正常；**一直 `X` 且 PC 不动** 优先查 mif / 路径。

---

## 7. 本次遇到的问题与处理（排错备忘）

按实际排查顺序记录，便于复现与助教答疑。

### 7.1 工程 / 环境类

| 现象 | 原因 | 处理 |
|------|------|------|
| 起始页不知如何建工程 | 未执行官方 tcl | `cd` 到 `run_vivado` 后 `source create_project.tcl` |
| 综合报 IP / `clk_pll` 错 | 2018.3 与更高版本 IP 不匹配 | ex1 **只做行为仿真**，先不综合 |
| Sources 里 coe 黄问号 | 初始化文件路径丢失 | 拷贝 `ex1_obj` 到 `func/obj`，修正/替换文件 |
| `$fopen` / `$readmemb` 失败 | Windows 相对路径不对 | 改为本机绝对路径 |

### 7.2 功能类（仿真已能跑但对比失败）

| 现象 | 原因要点 | 处理 |
|------|----------|------|
| PC 一直 `0x1c000000` | 指令 RAM 未加载 | 拷贝 `ex1_obj` → `func/obj`，重新仿真 |
| `Error!!!`：ref 在 `0x1c010000` 写 `r4=0xbfaff000`，mycpu 停在后面 PC 且 `wdata=X` | 分支后第一条 `lu12i` 未正确提交；同步 RAM 下冲刷后误取了 `PC+4` | 修正 `IF_stage`：分支冲刷后用 `fs_refill` **重取当前 `fs_pc`**，并区分复位后首次取指 |
| ALU 相关结果异常 | 模板 `alu.v` 中 OR / 移位等故意错误 | 按正确语义修复 `or`、`sll/srl/sra` 等 |

**分支 + 同步指令 RAM 的关键点：**

1. 分支命中：取消错误指令进入 ID（`fs_to_ds_valid` 拉低），PC 改为目标地址。  
2. 下一拍不能直接对同步 RAM 请求 `target+4`，否则读出指令与当前 PC 错位。  
3. 冲刷后应再取一次 **目标地址本身**，待有效指令进入 IF 后再顺序 `+4`。

### 7.3 重新验证时注意

修改 RTL 后必须：

1. 保存文件并确认 Windows 工程已更新到最新代码  
2. **重新 Run Behavioral Simulation**（重新编译）  
3. 再 **Run All**  
4. 看是否仍有 `Error!!!`，最终是否 `----PASS!!!`

---

## 8. 标准操作清单（建议按此执行）

把下面当作每次验收的 checklist：

1. [ ] `myCPU` 最新代码已同步到 Windows  
2. [ ] `for_test_obj/ex1_obj/*` 已覆盖到 `mycpu_env/func/obj/`  
3. [ ] `golden_trace.txt` 存在，且 `mycpu_tb.v` 路径正确  
4. [ ] `sync_ram.v` 中 mif 绝对路径正确  
5. [ ] 打开 `loongson.xpr`（或重新 `source create_project.tcl`）  
6. [ ] **Run Behavioral Simulation**（不要先综合）  
7. [ ] **Run All**  
8. [ ] Tcl Console 出现 **`----PASS!!!`**  
9. [ ] 截图 / 保存日志作为实验证据  

---

## 9. 本次验证结果

| 项目 | 结果 |
|------|------|
| 测试 | ex1（不考虑数据相关的五级流水） |
| 工程 | `soc_bram` → `loongson.xpr` |
| 结束时间 | 约 `2060335 ns` |
| 结论 | **`----PASS!!!`** |

日志摘要：

```text
==============================================================
Test end!
----PASS!!!
$finish called at time : 2060335 ns : File ".../mycpu_tb.v" Line 270
```

---

## 10. 通过后建议

1. **留存证据**：控制台 `PASS!!!` 截图 + 本验证说明  
2. **代码备份**：`git commit` / `push` 当前可过仿真的 `myCPU`  
3. **可选硬件验证**：按 `cdp_ede_remote` 流程出 bit 上传平台（仿真通过后再做）  
4. **下一实验**：  
   - **ex2**：阻塞处理数据相关 → 换 `ex2_obj`，重新生成/替换 golden_trace 后再仿  
   - **ex3**：前递  

更换 `exn_obj` 时，务必同步更新：

- `func/obj` 下的 mif/coe  
- `gettrace` 对应的 `golden_trace.txt`  
- 测试台 / sync_ram 中的路径（若使用绝对路径）

---

## 11. 一句话回顾

**把 ex1 的 mif 放到 `func/obj`，准备好 `golden_trace.txt`，用 `create_project.tcl` 打开 soc_bram 工程，只跑 Behavioral Simulation → Run All，在 Tcl Console 看到 `----PASS!!!` 即验收通过；本次关键修通点是同步 RAM 下分支冲刷后的 IF 重取逻辑，以及模板 ALU 中的已知错误。**
