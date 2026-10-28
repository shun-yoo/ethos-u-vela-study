# 새 터미널에서 한 번 실행: source scripts/env.sh
# vela(.venv), arm-none-eabi-gcc, fvp-u55를 이 터미널에서 쓸 수 있게 한다.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_ROOT/.venv/bin/activate"
export PATH="$_ROOT/tools/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin:$_ROOT/scripts:$PATH"
unset _ROOT
