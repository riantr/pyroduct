///|
/// Tests for the English rendering layer (`en.mbt`).
///
/// The match statements there are exhaustive, so the compiler already refuses to
/// compile when an enum gains a variant. What the compiler cannot check is the
/// property that actually matters to a consumer: that the English strings are
/// actually English, and actually distinct from the Chinese source layer they
/// sit beside. Both are asserted here rather than assumed.
///
/// Test names are in English, matching the file under test.

///|
/// True when every character is ASCII, i.e. the string cannot contain any
/// Chinese source wording. This is the invariant the whole layer exists to
/// guarantee.
fn all_ascii(s : String) -> Bool {
  for c in s.iter() {
    if !c.is_ascii() {
      return false
    }
  }
  true
}

///|
/// Every subject state has an English name and gloss, and neither is the
/// Chinese source layer wearing an English label.
test "thirty-four states carry distinct, non-Chinese English names and glosses" {
  let states = @src.all_states()
  assert_eq(states.length(), 34)
  let seen : Array[String] = []
  for s in states {
    let en = s.en_label()
    let en_g = s.en_gloss()
    assert_true(en.length() > 0)
    assert_true(en_g.length() > 0)
    assert_true(all_ascii(en))
    assert_true(all_ascii(en_g))
    assert_true(en != s.label())
    assert_true(en_g != s.gloss())
    // Distinctness matters: two states sharing an English name would make the
    // rendered page ambiguous rather than merely abbreviated.
    for prev in seen {
      assert_true(prev != en)
    }
    seen.push(en)
  }
}

///|
/// The eight drive slots carry an English designation and gloss.
test "eight drive slots carry English designation and gloss" {
  let slots = @src.all_slots()
  assert_eq(slots.length(), 8)
  for k in slots {
    let en_d = k.en_designation()
    assert_true(en_d.length() > 0)
    assert_true(all_ascii(en_d))
    assert_true(all_ascii(k.en_gloss()))
    assert_true(en_d != k.designation())
    assert_true(k.en_gloss() != k.gloss())
  }
}

///|
/// The eleven phases and every trigger have English names.
test "eleven phases and every trigger carry English names" {
  let phases = @src.all_phases()
  assert_eq(phases.length(), 11)
  for p in phases {
    assert_true(p.en_label().length() > 0)
    assert_true(all_ascii(p.en_label()))
    assert_true(p.en_label() != p.label())
  }
  let triggers = @src.all_triggers()
  assert_eq(triggers.length(), 49)
  for t in triggers {
    assert_true(t.en_label().length() > 0)
    assert_true(all_ascii(t.en_label()))
    assert_true(t.en_label() != t.label())
  }
}

///|
/// The five receipts are the English vocabulary a loop engine can branch on,
/// and each is distinct from the one-character Chinese receipt it replaces.
test "the five outcome receipts render in English" {
  let no_triggers : Array[@src.Trigger] = []
  let no_routes : Array[(@src.Trigger, @src.SubjectState)] = []
  let outcomes = [
    @src.Moved(@src.TakeStand, @src.Standing),
    @src.Held(@src.TakeStand, @src.Standing),
    @src.Open(no_routes),
    @src.Same(@src.Act, no_triggers, @src.Standing),
    @src.Block("gap"),
  ]
  let expected = ["Moved", "Held", "Undecided", "Converge", "No Edge"]
  for i = 0; i < outcomes.length(); i = i + 1 {
    let o = outcomes[i]
    let en = o.en_label()
    assert_eq(en, expected[i])
    assert_true(all_ascii(en))
    assert_true(en != o.label())
  }
}
