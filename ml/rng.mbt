///|
/// 可复现的伪随机数（splitmix64）：实验可重放，不依赖任何外部随机源。

///|
/// 一个确定性的伪随机数发生器。
pub struct Rng {
  mut state : UInt64
}

///|
/// 以 `seed` 初始化。
pub fn Rng::new(seed : UInt64) -> Rng {
  { state: seed, }
}

///|
/// 下一个 64 位随机数。
pub fn Rng::next_u64(self : Rng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
  z = (z ^ (z >> 27)) * 0x94D049BB133111EB
  z ^ (z >> 31)
}

///|
/// [0,1) 上的均匀数。
pub fn Rng::uniform(self : Rng) -> Double {
  (self.next_u64() >> 11).to_double() / 9007199254740992.0
}

///|
/// 近似标准正态（12 个均匀数之和，方差恰为 1）。
pub fn Rng::normal(self : Rng) -> Double {
  let mut s = 0.0
  for i = 0; i < 12; i = i + 1 {
    s += self.uniform()
  }
  s - 6.0
}

///|
/// Fisher–Yates 洗牌（就地）。
pub fn Rng::shuffle(self : Rng, idx : Array[Int]) -> Unit {
  let mut i = idx.length() - 1
  while i > 0 {
    let j = (self.uniform() * (i + 1).to_double()).to_int()
    let t = idx[i]
    idx[i] = idx[j]
    idx[j] = t
    i -= 1
  }
}
