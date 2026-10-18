///|
/// Tests for the English rendering layer (`en.mbt`).
///
/// The match statements there are exhaustive, so the compiler already refuses to
/// compile when an enum gains a variant. What the compiler cannot check is the
/// property that actually matters to a consumer: that the English strings are
/// actually English, and actually distinct from the Chinese source layer they
/// sit beside. Both are asserted here rather than assumed.
///

///|
/// A third property is asserted too, and it is the one that keeps the others
/// honest: the *chosen words themselves*. Each name was picked against what its
/// construct actually is, not by transliterating the Chinese, so `Cultivation`
/// and `Self-binding` are decisions rather than the only spellings that
/// compile. An earlier version of this file checked shape but not wording, and
/// the whole suite stayed green when every one of those decisions was reverted —
/// which is the state this file now refuses to sit in.
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
  // The words themselves are the decision, so they are pinned. `decided` has
  // as many entries as `seen` and every one of them is in `seen`, whose entries
  // the loop above proved pairwise distinct — so the two sets are equal and no
  // name outside this list can reach a reader.
  let decided = [
    "No Past", "Aimless", "Standing", "Freedom", "Urgency", "Alienation", "Emptiness",
    "Busyness", "Selfhood", "Interweaving", "Choosing", "Encounter", "Opening", "Evil",
    "Shame", "Guilt", "Self-binding", "Secret", "Suffering", "Loss", "Idol", "Order",
    "Sublime", "Passion", "Honor", "Awe", "Habit", "Reflection", "Dizziness", "Harmony",
    "Model", "Marking", "Cultivation", "Tranquility",
  ]
  assert_eq(decided.length(), states.length())
  for name in decided {
    assert_true(seen.contains(name))
  }
  // The glosses are how this whole change slipped through. A gloss is prose
  // about the source rather than a name, so nobody looked at it — and 修习's
  // gloss went on calling the state "discipline" in the very commit that
  // renamed it. Assert the reading positively: the gloss must say the word the
  // designation now wears. A negative test ("must not say discipline") would
  // also have to survive an unrelated sentence using the ordinary word, and a
  // check that misfires teaches you to ignore it.
  assert_true(@src.Discipline.en_gloss().contains("cultivation"))
  assert_true(@src.RemoveReefs.en_label().contains("cultivation"))
}

///|
/// The eight drive slots carry an English designation and gloss.
test "eight drive slots carry English designation and gloss" {
  let slots = @src.all_slots()
  assert_eq(slots.length(), 8)
  let seen : Array[String] = []
  for k in slots {
    let en_d = k.en_designation()
    assert_true(en_d.length() > 0)
    assert_true(all_ascii(en_d))
    assert_true(all_ascii(k.en_gloss()))
    assert_true(en_d != k.designation())
    assert_true(k.en_gloss() != k.gloss())
    seen.push(en_d)
  }
  // All eight are structural relations, so all eight are named like one. 处境
  // reads `Situation` because an occasion is a particular ceremony, and 先行
  // reads `Antecedent` because the slot is the relation, not the anticipation
  // it produces.
  let decided = [
    "Situation", "Orientation", "Antecedent", "Action", "Feedback", "Holding", "Co-being",
    "Unveiling",
  ]
  assert_eq(decided.length(), slots.length())
  for name in decided {
    assert_true(seen.contains(name))
  }
}

///|
/// The eleven phases and every trigger have English names.
test "eleven phases and every trigger carry English names" {
  let phases = @src.all_phases()
  assert_eq(phases.length(), 11)
  let seen : Array[String] = []
  for p in phases {
    assert_true(p.en_label().length() > 0)
    assert_true(all_ascii(p.en_label()))
    assert_true(p.en_label() != p.label())
    seen.push(p.en_label())
  }
  // One word per phase, like every other construct. The descriptive phrases
  // these replaced ("The Arising of Freedom", "Evil, Shame, Guilt,
  // Self-binding") were not wrong, but they went stale the moment a state
  // joined a phase, and what a phase contains is the members list's job.
  let decided = [
    "Natural", "Release", "Becoming", "Otherness", "Bondage", "Anguish", "Idolatry",
    "Glory", "Recollection", "Upbringing", "Serenity",
  ]
  assert_eq(decided.length(), phases.length())
  for name in decided {
    assert_true(seen.contains(name))
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
  let expected = ["Moved", "Held", "Undecided", "Converge", "No-way"]
  for i = 0; i < outcomes.length(); i = i + 1 {
    let o = outcomes[i]
    let en = o.en_label()
    assert_eq(en, expected[i])
    assert_true(all_ascii(en))
    assert_true(en != o.label())
  }
}
