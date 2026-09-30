///|
/// 本目录的由来：一次「读取 truth.pdf」的尝试及其结论。
///
/// 可复核的事实：
///
/// - truth.pdf 共 85 页、1025132 字节、PDF 1.6；元数据里 Title／Author／Producer
///   全为空，八十五条页流都在，414 个对象。
/// - 它是**加过密的**：`/Filter/Standard`、`/V 4`、`/R 4`，带 `/CF` + `/StmF` + `/StrF`，
///   trailer 里 `/Encrypt 415 0 R`；权限位 `/P = 4294967284`（按位解读：允许打印与
///   摘录，不允许修改）。
/// - 因此 181 条 FlateDecode 流**一条也解不开**（InvalidFlateData），
///   `pdf_read_document_from_bytes` 能拿到页树却读不出正文；连书签的字符串也是密文
///   ——所有书签共享同一个 16 字节前缀，这是流密码（RC4）的特征。
/// - `moonbitlang/pdflite` 走到 `decrypt_with_passwords` 时抛
///   `EncryptionDictionaryEntryExpected`：它无法解析这份 /Encrypt 字典。
///
/// 结论：正文没有读出来，这是加密＋工具限制，不是路径或参数问题。要重做抽取，
/// 请先准备未加密（或已知口令）的副本，然后：
///
///     moon add moonbitlang/pdflite
///     moon add moonbitlang/async
///
/// 再用 `doc.test_extract_text(页号数组)` 把每页的 UTF-8 文本写出来
/// （注意：`composition_text` 返回的是占用统计，不是正文；`bookmarks_json_blob`
/// 在这份文件上会失败，`read_bookmarks(preserve_actions=false)` 可用但文本已加密）。

///|
/// 勘察要点，供报告与 CLI 直接打印。
pub fn truth_pdf_facts() -> String {
  [
    "- truth.pdf：85 页，1025132 字节，PDF 1.6，Title／Author／Producer 均为空。",
    "- 加密参数：/Filter/Standard，/V 4，/R 4，/CF + /StmF + /StrF，/Encrypt 415 0 R。",
    "- 权限位 /P = 4294967284：允许打印与摘录，不允许修改。", "- 后果：181 条 FlateDecode 流全部 inflate 失败；书签字符串亦为密文（共享 16 字节前缀 ⇒ 流密码）。",
    "- pdflite 在 decrypt_with_passwords 抛 EncryptionDictionaryEntryExpected，读不动 /Encrypt 字典。",
    "- 重做抽取需要未加密副本：moon add moonbitlang/pdflite && moon add moonbitlang/async。",
  ].join("\n")
}
