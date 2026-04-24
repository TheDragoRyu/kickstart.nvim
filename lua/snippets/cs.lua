local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local fmt = require('luasnip.extras.fmt').fmt

-- Helper: current filename without extension, PascalCase assumed
local function filename()
  return vim.fn.expand '%:t:r'
end

-- ─── MonoBehaviour ────────────────────────────────────────────────────────────

ls.add_snippets('cs', {

  -- mono: full MonoBehaviour class stub
  s('mono', fmt([[
using UnityEngine;

public class {} : MonoBehaviour
{{
    private void Start()
    {{
        {}
    }}

    private void Update()
    {{
        {}
    }}
}}
]], { f(filename), i(1), i(2) })),

  -- lifecycle stubs
  s('awake', fmt([[
private void Awake()
{{
    {}
}}
]], { i(1) })),

  s('start', fmt([[
private void Start()
{{
    {}
}}
]], { i(1) })),

  s('update', fmt([[
private void Update()
{{
    {}
}}
]], { i(1) })),

  s('fixedupdate', fmt([[
private void FixedUpdate()
{{
    {}
}}
]], { i(1) })),

  s('onenable', fmt([[
private void OnEnable()
{{
    {}
}}
]], { i(1) })),

  s('ondisable', fmt([[
private void OnDisable()
{{
    {}
}}
]], { i(1) })),

  -- sf: SerializeField
  s('sf', fmt('[SerializeField] private {} _{};', { i(1, 'Type'), i(2, 'field') })),

  -- hdr: Header attribute
  s('hdr', fmt('[Header("{}")]', { i(1) })),

  -- co: Coroutine
  s('co', fmt([[
private IEnumerator {}()
{{
    {}
    yield return new WaitForSeconds({});
}}
]], { i(1, 'RoutineName'), i(2), i(3, '1f') })),

  -- dlog: Debug.Log with interpolation
  s('dlog', fmt('Debug.Log($"{{{}}}: {{{}}}");', { i(1, 'label'), i(2, 'value') })),

  -- singleton: Unity singleton pattern
  s('singleton', fmt([[
public static {} Instance {{ get; private set; }}

private void Awake()
{{
    if (Instance != null && Instance != this)
    {{
        Destroy(gameObject);
        return;
    }}
    Instance = this;
    {}
}}
]], { f(filename), i(1) })),

-- ─── DOTS / ECS (Unity 6) ─────────────────────────────────────────────────────

  -- isystem: ISystem stub
  s('isystem', fmt([[
using Unity.Entities;

public partial struct {} : ISystem
{{
    public void OnCreate(ref SystemState state)
    {{
        {}
    }}

    public void OnUpdate(ref SystemState state)
    {{
        {}
    }}

    public void OnDestroy(ref SystemState state)
    {{
        {}
    }}
}}
]], { i(1, 'MySystem'), i(2), i(3), i(4) })),

  -- icomp: IComponentData struct
  s('icomp', fmt([[
using Unity.Entities;

public struct {} : IComponentData
{{
    public {};
}}
]], { i(1, 'MyComponent'), i(2, 'float Value') })),

  -- iaspect: IAspect struct
  s('iaspect', fmt([[
using Unity.Entities;

public readonly partial struct {} : IAspect
{{
    {}
}}
]], { i(1, 'MyAspect'), i(2) })),

  -- ijob: IJobEntity stub
  s('ijob', fmt([[
using Unity.Entities;
using Unity.Burst;

[BurstCompile]
public partial struct {} : IJobEntity
{{
    private void Execute({})
    {{
        {}
    }}
}}
]], { i(1, 'MyJob'), i(2, 'ref MyComponent comp'), i(3) })),

  -- sysg: System with UpdateInGroup attribute
  s('sysg', fmt([[
using Unity.Entities;

[UpdateInGroup(typeof({}))]
public partial struct {} : ISystem
{{
    public void OnUpdate(ref SystemState state)
    {{
        {}
    }}
}}
]], { i(1, 'SimulationSystemGroup'), i(2, 'MySystem'), i(3) })),

})
