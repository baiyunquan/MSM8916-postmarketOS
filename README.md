# MSM8916 postmarketOS 多板型镜像

[![Validate device trees](https://github.com/baiyunquan/MSM8916-postmarketOS/actions/workflows/validate.yml/badge.svg)](https://github.com/baiyunquan/MSM8916-postmarketOS/actions/workflows/validate.yml)

本仓库把 `debian-dtbs` 中的 MSM8916 设备树移植到 `postmarketOS` 的
`linux-postmarketos-qcom-msm8916` 内核构建流程中。最终只生成一套 split
boot/root 镜像，boot 分区同时携带 19 款 DTB；具体型号通过
`/boot/extlinux/extlinux.conf` 中的 `fdt` 行选择。

当前验收范围是 CI、19 款 DTB 编译/结构检查、boot 镜像内容检查和校验和检查。
除 postmarketOS 原生支持的板型外，尚未宣称已完成真机启动、调制解调器、Wi-Fi、
LED、按键、屏幕或充电功能验证。

## 设计与来源

- `pmos-example` 固定到已成功生成 modem-ready postmarketOS 构件的提交，用作
  pmbootstrap、固件和 lk1st/qhypstub 构建参考。
- `debian-dtbs` 固定到包含完整 19 款板型清单的提交，提供 14 个可重编译 DTS
  以及 2 个仅有二进制形式的 DTB。
- `thwc-ufi001c`、`thwc-uf896`、`yiming-uz801v3` 直接使用固定内核标签
  `v6.12.1-msm8916` 中的原生设备树。
- SP970 的旧 UART pinctrl 引用、MiFi 的 `id-gpios` 属性和 MF32 的 LED/USB
  引用在 staging 时通过最小兼容补丁适配到该内核标签；参考 submodule 不被修改。

构建固定使用以下上游版本，避免 GitHub Actions 每次跟随上游 `main` 漂移：

| 组件 | 固定版本 |
|---|---|
| pmbootstrap | `b2bf3539cd92acce4ab187167581168e845f3e7e` |
| pmaports | `1ce58c5ae1b7573c6471959c4ab406391eefb103` |
| MSM8916 内核 | `v6.12.1-msm8916` |
| pmOS 参考 | `fe4289d03aaf95fd2325e81b12ff02b55b70e868` |
| Debian DT 参考 | `ef731fa31eefdf5730f87e31d9aecafe61159ed2` |

## 支持的板型

默认选择 `thwc-ufi001c`。完整映射也会写入 boot 镜像根目录的
`/boards.conf`，并随发布包保存为 `boards.conf`。

| 板型 ID | DTB | 来源 |
|---|---|---|
| `fy-mf800` | `msm8916-fy-mf800.dtb` | Debian 二进制 DTB |
| `generic-m9s` | `msm8916-generic-m9s.dtb` | Debian DTS |
| `generic-mf68e` | `msm8916-generic-mf68e.dtb` | Debian DTS |
| `generic-uf02` | `msm8916-generic-uf02.dtb` | Debian DTS |
| `gexing-sp970` | `msm8916-gexing-sp970.dtb` | Debian DTS |
| `gexing-sp970v10` | `msm8916-gexing-sp970v10.dtb` | Debian DTS |
| `gexing-sp970v11` | `msm8916-gexing-sp970v11.dtb` | Debian DTS |
| `jz01-45-v33` | `msm8916-jz01-45-v33.dtb` | Debian 二进制 DTB |
| `thwc-jz02v10` | `msm8916-thwc-jz02v10.dtb` | Debian DTS |
| `thwc-qrzl903` | `msm8916-thwc-qrzl903.dtb` | Debian DTS |
| `thwc-uf896` | `msm8916-thwc-uf896.dtb` | 内核原生 |
| `thwc-ufi001b` | `msm8916-thwc-ufi001b.dtb` | Debian DTS |
| `thwc-ufi001c` | `msm8916-thwc-ufi001c.dtb` | 内核原生 |
| `thwc-ufi003` | `msm8916-thwc-ufi003.dtb` | Debian DTS |
| `thwc-ufi103s` | `msm8916-thwc-ufi103s.dtb` | Debian DTS |
| `thwc-w001` | `msm8916-thwc-w001.dtb` | Debian DTS |
| `ufi-mf32` | `msm8916-ufi-mf32.dtb` | Debian DTS |
| `xinxun-wf2` | `msm8916-xinxun-wf2.dtb` | Debian DTS |
| `yiming-uz801v3` | `msm8916-yiming-uz801v3.dtb` | 内核原生 |

## 构建与发布

在 GitHub 仓库的 **Actions → Build postmarketOS multi-board image → Run
workflow** 手动触发完整构建。工作流会：

1. 检出所有固定 submodule；
2. 为 pmaports 内核包加入 19 款 DTB 并从源码重建内核；
3. 生成带 ModemManager/QMI/QRTR 的 console postmarketOS split 镜像；
4. 把 extlinux 默认 `fdt` 改为 `/dtbs/qcom/msm8916-thwc-ufi001c.dtb`；
5. 检查 boot 镜像内 19 个 DTB 的 `compatible`，生成 `SHA256SUMS`；
6. 同时上传 Actions Artifact，并创建预发布 GitHub Release。

发布包 `postmarketos-msm8916-multiboard.tar.gz` 的主要内容：

```text
boards.conf
SHA256SUMS
source-versions.txt
dtbs/                              # 19 个经过检查的 DTB
bootloaders/
  hyp.mbn
  tz.mbn
  aboot-thwc-ufi001c.mbn
  aboot-thwc-uf896.mbn
  aboot-yiming-uz801v3.mbn
export/
  zhihe-generic-boot.img           # ext2 /boot，包含全部 19 个 DTB
  zhihe-generic-root.img           # btrfs rootfs
  boot.img
  initramfs
  vmlinuz
```

镜像默认账户为 `user`，初始密码为 `147147`。首次启动后应立即修改密码。

## 选择设备树

首次刷写前，建议在 Linux 主机上修改 boot 镜像：

```sh
sudo mkdir -p /mnt/pmos-boot
sudo mount -o loop export/zhihe-generic-boot.img /mnt/pmos-boot
sudo sed -i \
  's#^[[:space:]]*fdt .*#\tfdt /dtbs/qcom/msm8916-gexing-sp970v11.dtb#' \
  /mnt/pmos-boot/extlinux/extlinux.conf
sudo umount /mnt/pmos-boot
```

把示例 DTB 文件名替换为上表对应项。系统已经可以启动时，也可以直接修改
`/boot/extlinux/extlinux.conf`，然后重启。选择错误的 DTB 可能导致无法启动或外设
工作异常。

## 刷写注意事项

刷写 bootloader、分区表、`tz` 或 `hyp` 有变砖风险。开始前至少完成整机 EDL
备份，并阅读 postmarketOS 的
[Zhihe 系列设备页面](https://wiki.postmarketos.org/wiki/Zhihe_series_LTE_dongles_(generic-zhihe))。
上游特别警告不要把 DragonBoard 的 `tz` 与原厂 `hyp` 混用，也不再建议无差别
替换 `rpm`/`sbl1`。

此发布包中的系统镜像是多板型的，但 lk1st 并非自动识别全部 19 款硬件。只提供
上游明确存在设备节点的 UFI001C、UF896、UZ801 V3 三个 aboot 变体；其他板型
应保留已知可用的 bootloader，或在真机确认兼容关系后选择最接近的变体。

官方推荐的 split 方案是把 `zhihe-generic-boot.img` 写入可用的 boot/cache
分区，把转换为 Android sparse 格式的 root 镜像写入 system 或 userdata。具体分区
因设备而异，仓库不会自动执行刷写。

## 本地验证

Ubuntu/WSL 中可对固定内核源码执行全部 DTB 编译检查：

```sh
git clone --depth=1 --branch v6.12.1-msm8916 \
  https://github.com/msm8916-mainline/linux.git /tmp/linux-msm8916
bash scripts/validate-dtbs.sh /tmp/linux-msm8916 /tmp/validated-dtbs
```

完整镜像构建建议使用仓库 workflow；它还会验证 ext2 boot 镜像内部的 DTB 数量、
`compatible`、extlinux 路径以及发布包校验和。

## 许可证

根仓库的原创脚本和文档采用 MIT 许可证。submodule 保留各自许可证；设备树源码及
相关兼容补丁遵循文件中的 `GPL-2.0-only` 声明。两个预编译 DTB 原样来自固定的
`debian-dtbs` 提交，其可审查性和跨内核兼容性低于源码构建的 DTB。
