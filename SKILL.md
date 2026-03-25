---
name: etds_sr_ov_pack
description: 使用 ETDS + OpenVINO 进行视频2x超分处理。自动处理环境依赖，支持 Intel AMX BF16 加速。
---

## 目标

 **2倍超分辨率放大**（宽高各 ×2），例如 480p → 960p、720p → 1440p。使用 ETDS（Efficient and Degradation-aware Temporal Super-Resolution）轻量模型，通过 OpenVINO 在 Intel CPU 上高效推理。

## 适用场景

- AI 生成的视频（如 Seedance、Sora 等）输出分辨率较低，需要放大到更高清
- 老旧视频、低分辨率素材的画质增强
- 需要在 **纯 CPU 环境**（无 GPU）下完成超分的场景
- 对画质要求较高但可接受逐帧处理耗时的离线任务

## 执行流程

 exec 工具执行以下命令（只替换 `<输入视频>` 为绝对路径）：

```bash
bash /home/node/.openclaw/workspace/skills/etds_sr_ov_pack/run.sh <输入视频>
```

cd .. `原文件名_sr2x_ov.mp4`。

cd ..

```bash
bash /home/node/.openclaw/workspace/skills/etds_sr_ov_pack/run.sh <输入视频> -o <输出视频绝对路径>
```

## 注意事项

- 将 `<输入视频>` 替换为实际视频文件的 **绝对路径**
- **不要修改命令中的其他参数**，直接复制使用，只替换路径
- **不要创建或调用任何额外脚本文件**，直接用 exec 工具执行上面的命令
- 输出格式固定为 MP4（H.264 编码，CRF 18），如源视频含音频会自动合并（AAC 编码）
- 处理过程中会实时打印进度（帧数、fps），可据此判断剩余时间

## 限制

- **仅支持 2x 放大**，不支持 3x/4x 等其他倍率（模型固定为 2x）
- **仅支持 Linux x86_64** 平台（OpenVINO CPU plugin 的限制）
- **逐帧处理**，不利用帧间信息，非时序超分（尽管模型名为 ETDS）
- 超大分辨率输入（如 4K → 8K）会占用大量内存，可能 OOM
- 输出编码固定为 libx264，无法选择 H.265/AV1 等
- 不支持 GPU 加速（仅 CPU 推理）

## 规则

- 输入必须是 ffmpeg 能解码的视频格式（mp4、mkv、avi、mov、webm 等）
- 输入路径不能包含特殊 shell 字符（空格需用引号包裹）
- 若输出文件已存在会被 **覆盖**，不会提示确认
- 同一时间 **不要并行运行多个超分任务**，会争抢 CPU 资源导致都变慢

## 性能参考

 Intel Xeon 6982P-C（支持 AMX）上的实测数据（864×496 → 1728×992）：

| 指标 | 数值 |
|---|---|
| 模型精度 | FP32 模型，OpenVINO 自动 BF16 AMX 加速 |
| 纯推理速度 | ~14 fps（72 ms/帧） |
| 总管线速度（含编解码） | ~7 fps |
| BF16 vs FP32 加速比 | 5.5x |
| 模型大小 | 376 KB（xml + bin） |

 AMX 的旧款 CPU 会回退到 FP32/AVX512，速度约为上表的 1/5。

## 已完成的安装

#"Done" 
cd ..

1. **Python venv**（`.venv/`）— 通过 `python3 -m venv --without-pip` 创建，再用 `get-pip.py` 引导安装 pip
2. **Python 依赖**（pip 安装在 `.venv` 内）：
   - `openvino==2025.2.0` — OpenVINO 推理引擎（含 CPU plugin 和 Python 绑定）
   - `numpy` — 数值计算
   - `opencv-python-headless` — 视频帧读取和色彩空间转换
3. **ffmpeg / ffprobe** — run.sh 自动检测：优先使用系统自带版本，若不存在则自动下载静态编译版到 `bin/`
4. **ETDS 模型**（`model/ETDS_M7C48_x2.xml` + `.bin`）— OpenVINO IR 格式，随包附带

## 目录结构

```
etds_sr_ov_pack/
 run.sh              # 入口脚本，自动处理环境和依赖
 sr_video_ov.py      # Python 主程序（推理 + 编码管线）
 SKILL.md            # 本文件（OpenClaw skill 文档）
 model/
   ├── ETDS_M7C48_x2.xml   # OpenVINO IR 模型结构
   └── ETDS_M7C48_x2.bin   # OpenVINO IR 模型权重（300KB）
 .venv/              # Python 虚拟环境（含 openvino、numpy、cv2）
 bin/                # ffmpeg/ffprobe（自动生成，首次运行时创建）
```

## OpenClaw 配置约定

- Skill 名称：`etds_sr_ov_pack`
- 调用方式：仅通过 `bash run.sh` 执行，不直接调用 `sr_video_ov.py`
- run.sh 是完全自包含的入口，会自动：激活 venv → 检查依赖 → 确保 ffmpeg → 执行推理
- 输入参数仅需一个视频路径，输出路径可选
- 不需要预设任何环境变量（无需 `source setupvars.sh`、无需设 `PYTHONPATH`）

## 故障排查

### 1. `Error: Python 3.9+ not found`

**原因**：系统没有 Python 3.9 或更高版本。

**修复**：
```bash
apt-get update && apt-get install -y python3.11
```

### 2. `ModuleNotFoundError: No module named 'numpy'` 或 `cv2` 或 `openvino`

**原因**：venv 损坏或依赖未安装。

**修复**：重建 venv：
```bash
cd /home/node/.openclaw/workspace/skills/etds_sr_ov_pack
rm -rf .venv
python3 -m venv --without-pip .venv
source .venv/bin/activate
curl -sS https://bootstrap.pypa.io/get-pip.py | python3
pip install openvino==2025.2.0 numpy opencv-python-headless
```

### 3. `Error: ffmpeg not found` 且自动下载失败

**原因**：无网络访问或 curl 不可用。

**修复**：手动安装系统 ffmpeg：
```bash
apt-get update && apt-get install -y ffmpeg
```
"Done" `bin/` 目录让 run.sh 重新检测：
```bash
rm -rf /home/node/.openclaw/workspace/skills/etds_sr_ov_pack/bin
```

### 4. ffmpeg `symbol lookup error` 或 `GLIBC` 相关报错

**原因**：`bin/` 中残留了旧的动态链接 ffmpeg（依赖 glibc 2.39，而系统是 2.36）。

**修复**：删除 bin/ 让 run.sh 重新获取：
```bash
rm -rf /home/node/.openclaw/workspace/skills/etds_sr_ov_pack/bin
```
run.sh 会自动检测系统 ffmpeg 或下载静态编译版，不存在 glibc 兼容问题。

### 5. 处理大分辨率视频时 OOM（内存不足）

**原因**：输入分辨率过大（如 2160p），2x 放大后单帧需大量内存。

**缓解**：先用 ffmpeg 缩小输入再超分，或指定推理线程数减少并行内存占用：
```bash
bash run.sh input.mp4 --nthreads 4
```

### 6. 输出视频无音频

**原因**：音频合并阶段 ffmpeg 报错（音频编解码器不支持等），脚本会回退为无音频输出。

**修复**：检查终端输出中的 `Audio merge warning` 信息。通常升级 ffmpeg 版本可解决。

### 7. `pip install` 报 `externally-managed-environment` 错误

**原因**：Debian 12+ 的 PEP 668 保护机制，禁止直接 pip install 到系统 Python。

**说明**：这是正常的，run.sh 使用 `.venv` 虚拟环境绕开此限制。**不要**使用 `--break-system-packages` 参数。若 .venv 不存在，按上面第 2 条重建即可。
