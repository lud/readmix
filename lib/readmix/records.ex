defmodule Readmix.Records do
  @moduledoc false
  require Record

  Record.defrecord(:generated,
    mod: nil,
    action: nil,
    params: [],
    section_name: nil,
    spec: nil,
    sub_blocks: [],
    rendered: []
  )
end
