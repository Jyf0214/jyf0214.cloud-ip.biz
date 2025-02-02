#!/bin/bash

# 打印一条消息，表明脚本已启动
echo "This script will never end. Press Ctrl+C to stop it."

# 无限循环
while true; do
    # 在这里可以执行一些操作，例如打印时间
    echo "The current time is: $(date)"
    
    # 等待一段时间（例如 5 秒）
    sleep 5
done
