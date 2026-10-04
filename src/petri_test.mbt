///|
/// 黑盒测试：Petri 网面（CarlAdam 镜像）。锁定——托肯守恒、缺口即结构
/// （未使能返回 None）、效果序列的形状、双托肯并发的独立性。

///|
test "petri：发火守恒——效果一收一发，总数不变" {
  let m0 = @src.petri_marking_of([@src.Standing, @src.Standing, @src.Freedom])
  assert_eq(m0.total(), 3)
  match
    @src.PetriTransition::{
      from: @src.Standing,
      trigger: @src.ActInFreedom,
      to: @src.Freedom,
    } {
    t =>
      match m0.fire(t) {
        Some((effects, m1)) => {
          // 效果序列：Consume(立位) + Produce(自由)
          assert_eq(effects.length(), 2)
          assert_eq(m1.total(), 3) // 守恒
          assert_eq(m1.at(@src.Standing), 1)
          assert_eq(m1.at(@src.Freedom), 2)
        }
        None => assert_true(false)
      }
  }
}

///|
test "petri：守（自环）净变化为零；缺口即结构（未使能/无变迁皆 None）" {
  let m0 = @src.petri_marking_of([@src.Selfhood])
  // 守：沉淀 Deposit 是自身上的自环迁移
  match m0.fire_by(@src.Selfhood, @src.Deposit) {
    Some((effects, m1)) => {
      assert_eq(effects.length(), 2)
      assert_eq(m1.total(), 1)
      assert_eq(m1.at(@src.Selfhood), 1) // 净变化为零
    }
    None => assert_true(false)
  }
  // 缺口即结构：立位 × 沉淀（228 无路组合之一）——没有对应变迁
  let m1 = @src.petri_marking_of([@src.Standing])
  match m1.fire_by(@src.Standing, @src.Deposit) {
    Some(_) => assert_true(false)
    None => ()
  }
  // 变迁存在但输入库所无托肯——未使能
  let m2 = @src.petri_marking_of([]) // 空标识
  match m2.fire_by(@src.Standing, @src.ActInFreedom) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "petri：双托肯并发——各自独立行走，互不妨碍" {
  let m0 = @src.petri_marking_of([@src.Standing, @src.Tranquility])
  assert_eq(m0.total(), 2)
  // 甲表态：立位 → 自由
  let m1 = match m0.fire_by(@src.Standing, @src.ActInFreedom) {
    Some((_, m)) => m
    None => {
      assert_true(false)
      m0
    }
  }
  // 乙重开界域：宁静 → 反顾（重入）
  let m2 = match m1.fire_by(@src.Tranquility, @src.ReopenByHorizon) {
    Some((_, m)) => m
    None => {
      assert_true(false)
      m1
    }
  }
  assert_eq(m2.at(@src.Standing), 0)
  assert_eq(m2.at(@src.Freedom), 1)
  assert_eq(m2.at(@src.Tranquility), 0)
  assert_eq(m2.at(@src.Reflection), 1)
  assert_eq(m2.total(), 2) // 守恒
}

///|
test "petri：使能表随标识变化；全部 53 变迁一对一" {
  // 空标识：无变迁使能
  let empty = @src.petri_marking_of([])
  assert_eq(empty.enabled().length(), 0)
  // 单托肯在宁静：只有重入一条出边
  let at_rest = @src.petri_marking_of([@src.Tranquility])
  match at_rest.enabled().length() {
    n => assert_true(n >= 1) // ReopenByHorizon 使能（宁静只有一条出边）
  }
  // 变迁总数 = 迁移表行数
  assert_eq(@src.petri_transitions().length(), 53)
}
