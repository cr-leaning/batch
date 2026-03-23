#!/bin/bash

# ==========================================
# 【内部用】バッチ起動コア処理（直接呼び出さないこと）
# $1     : サイズ (S/M/L)
# $2     : JARファイルのパス
# $3以降 : 追加のJVMオプション、またはSpring Boot引数（順不同でOK）
# ==========================================
function _run_batch_core() {
    local size_flag="$1"
    local target_jar="$2"
    shift 2 # $1(サイズ)と$2(JAR)を取り除く

    # JARの存在確認
    if [[ ! -f "$target_jar" ]]; then
        echo "[ERROR] JARファイルが見つかりません -> $target_jar"
        return 1
    fi

    # 1. 共通JVMオプション (Java 21向け)
    local common_opts=(
        "-XX:+UseG1GC"
        "-XX:MaxMetaspaceSize=256m"
        "-XX:+HeapDumpOnOutOfMemoryError"
        "-XX:HeapDumpPath=/var/log/myapp/dumps/"
        "-XX:+ExitOnOutOfMemoryError"
        "-Xlog:gc*:file=/var/log/myapp/gc_%p.log:time,uptime:filecount=5,filesize=10M"
    )

    # 2. サイズごとのJVMオプションベース設定
    local size_opts=()
    case "${size_flag}" in
        S) size_opts=("-Xms128m" "-Xmx512m" "-XX:TieredStopAtLevel=1") ;;
        M) size_opts=("-Xms256m" "-Xmx1g") ;;
        L) size_opts=("-Xms512m" "-Xmx2g") ;;
        *) echo "[ERROR] 未知のサイズ指定です -> $size_flag"; return 1 ;;
    esac

    # 3. 引数の自動振り分け処理
    local custom_jvm_opts=()
    local spring_args=()

    for arg in "$@"; do
        # -X, -D, -XX で始まるものはJVMオプションと判定
        if [[ "$arg" == -X* || "$arg" == -D* || "$arg" == -XX:* ]]; then
            custom_jvm_opts+=("$arg")
        else
            # それ以外（--spring... など）はSpring Bootの引数と判定
            spring_args+=("$arg")
        fi
    done

    # 4. 実行コマンドの出力（確認用）
    echo "========================================"
    echo "[INFO] 起動サイズ   : ${size_flag}"
    echo "[INFO] 実行JAR      : ${target_jar}"
    echo "[INFO] 追加JVM設定  : ${custom_jvm_opts[@]:-(なし)}"
    echo "[INFO] Spring引数   : ${spring_args[@]:-(なし)}"
    echo "========================================"

    # 5. 実行！（custom_jvm_opts を -jar の直前に置くことで後勝ちで上書きさせる）
    java "${common_opts[@]}" "${size_opts[@]}" "${custom_jvm_opts[@]}" -jar "$target_jar" "${spring_args[@]}"
}

# ==========================================
# 【公開用】各サイズ起動ラッパー関数
# $1     : JARファイルのパス
# $2以降 : JVMオプション(-Xmx等)、Spring引数(--xxx等)を順不同で指定可能
# ==========================================
function run_batch_s() {
    _run_batch_core "S" "$@"
}

function run_batch_m() {
    _run_batch_core "M" "$@"
}

function run_batch_l() {
    _run_batch_core "L" "$@"
}
