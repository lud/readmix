_mix_deps:
  out=$(mix deps.get) && echo "all dependencies fetched" || { echo "$out"; exit 1; }

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

_mix_format:
  mix format

_mix_check:
  mix libdev.check

_git_status:
  git status

readme:
  mix rdmx.update README.md

check: _mix_deps _mix_format _mix_check readme _git_status

