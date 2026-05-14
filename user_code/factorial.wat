(module
  (type (;0;) (func))
  (type (;1;) (func (param i64) (result i64)))
  (func (;0;) (type 0)
    global.get 0
    call 1
    global.set 1)
  (func (;1;) (type 1) (param i64) (result i64)
    (local i64)
    local.get 0
    local.set 1
    loop (result i64)  ;; label = @1
      local.get 1
      local.get 0
      i64.const 1
      i64.sub
      local.tee 0
      i64.mul
      local.set 1
      local.get 0
      i64.const 1
      i64.gt_u
      br_if 0 (;@1;)
      local.get 1
    end)
  (memory (;0;) 1)
  (global (;0;) (mut i64) (i64.const 12))
  (global (;1;) (mut i64) (i64.const 0))
  (global (;2;) (mut i64) (i64.const 0))
  (export "g0" (global 0))
  (export "g1" (global 1))
  (export "g2" (global 2))
  (export "fac" (func 1))
  (start 0))
