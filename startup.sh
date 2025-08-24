#!/bin/bash
set -e

# 从 GitHub Actions 传递的环境变量中读取上下文
# 如果是手动触发，则使用 INPUT_* 变量；如果是定时任务，则 GITHUB_EVENT_NAME 为 'schedule'
RUN_YUNZAI_INPUT="${INPUT_RUN_YUNZAI:-true}"
RUN_LOOPHOLE_WEBDAV_INPUT="${INPUT_RUN_LOOPHOLE_WEBDAV:-true}"
RUN_OPENLIST_INPUT="${INPUT_RUN_OPENLIST:-true}"

if [[ "$GITHUB_EVENT_NAME" == "schedule" ]]; then
  RUN_YUNZAI='true'
  RUN_LOOPHOLE_WEBDAV='true'
  RUN_OPENLIST='true'
else
  RUN_YUNZAI="${RUN_YUNZAI_INPUT}"
  RUN_LOOPHOLE_WEBDAV="${RUN_LOOPHOLE_WEBDAV_INPUT}"
  RUN_OPENLIST="${RUN_OPENLIST_INPUT}"
fi

# 根据逻辑绑定服务
RUN_LAUNCHER="${RUN_YUNZAI}"
RUN_CHMLFRP="${RUN_OPENLIST}"
ENABLE_NAPCAT_TUNNEL="${RUN_YUNZAI}"

# 设置必要的路径
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/node_modules/.bin
HOME_DIR="/root"

echo "--- [Chroot 环境内] 开始执行自动化启动任务 ---"
if ! command -v pm2 &> /dev/null; then
  npm install -g pm2
fi

echo "1. 清理旧日志..."
pm2 flush
find "${HOME_DIR}" -name "*.log" -type f -delete

if [[ "$RUN_LAUNCHER" == "true" ]]; then
  echo "2. [Yunzai联动] 启动 launcher..."
  [ -f "${HOME_DIR}/launcher.sh" ] && (cd "${HOME_DIR}" && pm2 start ./launcher.sh --name "launcher") || echo "  -> 警告: launcher.sh 未找到。"
else
  echo "2. [已禁用] 跳过 launcher。"
fi

echo "3. 启动 Redis (强制)..."
command -v redis-server &> /dev/null && redis-server --daemonize yes || echo "  -> 警告: redis-server 未找到。"

if [[ "$RUN_YUNZAI" == "true" ]]; then
  echo "4. 启动 Yunzai-Bot..."
  [ -d "${HOME_DIR}/Yunzai" ] && (cd "${HOME_DIR}/Yunzai" && pm2 start app.js --name "yunzai-app") || echo "  -> 警告: Yunzai 目录未找到。"
else
  echo "4. [已禁用] 跳过 Yunzai-Bot。"
fi

if [[ "$RUN_LOOPHOLE_WEBDAV" == "true" ]]; then
  echo "5. 启动 loophole..."
  if [ -f "${HOME_DIR}/loophole/loophole" ]; then
    cd "${HOME_DIR}/loophole"
    pm2 start ./loophole --name "loophole-webdav" -- webdav ~ -u "${LOOPHOLE_WEBDAV_USER}" -p "${LOOPHOLE_WEBDAV_PASS}" --hostname "${LOOPHOLE_WEBDAV_HOSTNAME}"
    if [[ "$ENABLE_NAPCAT_TUNNEL" == "true" ]]; then
      echo "  -> [Yunzai联动] 启用 Napcat 隧道..."
      pm2 start ./loophole --name "loophole-http" -- http 6099 --hostname "${LOOPHOLE_NAPCAT_HOSTNAME}" --basic-auth-username "${NAPCATUSER}" --basic-auth-password "${NAPCATPASS}"
    fi
  else
    echo "  -> 警告: loophole 未找到。"
  fi
else
  echo "5. [已禁用] 跳过 loophole。"
fi

if [[ "$RUN_OPENLIST" == "true" ]]; then
  echo "6. 启动 openlist..."
  [ -f "${HOME_DIR}/openlist" ] && (cd "${HOME_DIR}" && pm2 start ./openlist --name "openlist-server" -- server) || echo "  -> 警告: openlist 未找到。"
else
  echo "6. [已禁用] 跳过 openlist。"
fi

if [[ "$RUN_CHMLFRP" == "true" ]]; then
  echo "7. [OpenList联动] 启动 ChmlFrp..."
  [ -f "${HOME_DIR}/ChmlFrp/frpc" ] && (cd "${HOME_DIR}/ChmlFrp" && pm2 start ./frpc --name "chml-frp" -- -c frpc.ini) || echo "  -> 警告: frpc 未找到。"
  [ -f "${HOME_DIR}/ChmlFrp/frps" ] && (cd "${HOME_DIR}/ChmlFrp" && pm2 start ./frpc --name "chml-frps" -- -c frps.ini) || echo "  -> 警告: frps 未找到。"
else
  echo "7. [已禁用] 跳过 ChmlFrp。"
fi

echo "--- [Chroot 环境内] 任务派发完成，保存PM2进程列表 ---"
pm2 save && pm2 ls

echo "--- [Chroot 环境内] 启动 MAA 并连接到 Redroid 容器 ---"
# 注意: Redroid 的 ADB 服务暴露在 127.0.0.1:5555
maa startup --adb-path adb --address 127.0.0.1:5555