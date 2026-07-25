// Seed content: the djb hybrid-vs-solo-PQ debate, curated from the public
// argument chart in "NSA and IETF, part 6: The structure of the debate"
// (blog.cr.yp.to, 2026.02.21, version 2026.06.25).
//
// Technical branches only — the process/consensus-legitimacy branches of the
// chart ("the spec is procedurally improper", "objecting is procedurally
// improper") are deliberately omitted per PLAN.md.
//
// No AI paraphrasing: `text` is a neutral summary; `source` carries the
// verbatim wording (quotes as they appear in the chart) plus the link.

const SRC =
  "D. J. Bernstein, \u201cNSA and IETF, part 6: The structure of the debate\u201d \u2014 https://blog.cr.yp.to/20260221-structure.html";

function q(quote) {
  return `${quote}\n\nSource: ${SRC}`;
}

export const SEED_AUTHOR = "seed:djb-debate-chart";

// kind is relative to the parent: a `pro` supports its parent, a `con`
// attacks it (djb's chart semantics). Top-level entries are `answer`s to
// the space question.
export const SEED_TREE = [
  {
    kind: "answer",
    text: "Standardize solo ML-KEM: publish the RFC specifying pure ML-KEM key agreement in TLS.",
    source: q(
      "The proposal charted in the post: \u201cthe NSA-driven proposal for IETF to publish an RFC specifying usage of solo ML-KEM in TLS.\u201d"
    ),
    children: [
      {
        kind: "pro",
        text: "Regulatory compliance requires standalone PQ key establishment (NIST profiles, CNSA 2.0); many vendors will only ship ML-KEM-only TLS if a specific RFC exists.",
        source: q(
          "\u201cregulatory frameworks that require standalone post-quantum key establishment\u201d; \u201chybrid doesn't necessarily work for everyone\u201d; \u201cMany vendors will only support ML-KEM-only TLS if there is, specifically, an RFC from IETF specifying such\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "NSA's own official CNSA 2.0 documents say hybrids \u201cmay be allowed or required due to protocol standards\u201d \u2014 the written requirement does not mandate solo PQ.",
            source: q(
              "\u201cthe official NSA documents on CNSA 2.0 say 'hybrid solutions may be allowed or required due to protocol standards'; so far NSA's push for this spec consists of unofficial actions by NSA employees\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "Solo PQ is smaller and faster than ECC+PQ; hybrids require ad-hoc encodings.",
        source: q(
          "\u201cthe spec decreases cost; solo PQ is smaller and faster than ECC+PQ; hybrids require 'ad hoc encodings'; 'pure-mlkem is the obviously correct solution if you want high-performance solutions'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "The cost difference is minor: X25519 keys are 32 bytes next to ML-KEM's 800\u20131568-byte keys, so the ECC share of communication and computation is negligible.",
            source: q(
              "\u201cML-KEM keys are 800/1184/1568 bytes; X25519 keys are only 32 bytes; communication and computation costs of X25519 are negligible compared to communicating ML-KEM keys and ciphertexts\u201d"
            ),
          },
          {
            kind: "pro",
            text: "Some constrained environments can afford solo PQ but not ECC+PQ.",
            source: q(
              "\u201csome constrained environments can afford solo PQ but not ECC+PQ; 'constrained environments where smaller key sizes or less computation are needed'\u201d"
            ),
            children: [
              {
                kind: "con",
                text: "The cited sources don't claim 32 extra bytes are an issue, and reported legacy-middlebox problems with PQ key shares were fixed years ago.",
                source: q(
                  "\u201cthe second source says that legacy-middlebox problems with PQ were fixed years ago; the first and third sources don't claim legacy-middlebox problems; also, none of the sources claim that 32 extra bytes are an issue\u201d"
                ),
              },
            ],
          },
          {
            kind: "pro",
            text: "High-frequency trading needs the smallest possible latency.",
            source: q("\u201chigh-frequency trading needs the smallest possible latency\u201d"),
            children: [
              {
                kind: "con",
                text: "This is a key-exchange spec; key-exchange costs don't affect per-trade latency.",
                source: q(
                  "\u201cthat's irrelevant; this is a key-exchange spec; key-exchange costs do not affect trading latency\u201d"
                ),
              },
            ],
          },
        ],
      },
      {
        kind: "pro",
        text: "Hybrids are transitional by design; going straight to solo PQ avoids a second large-scale migration later.",
        source: q(
          "\u201c'hybrid PQ/T is clearly a transitional mechanism'; 'bridging technology'; better to 'make the future transition easier'; deploying hybrids would require a 'second large-scale engineering effort to migrate to pure ML-KEM sometime later'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "Even after a billion-dollar quantum computer starts breaking thousands of ECC keys per year, ECC+PQ will still rescue many more broken PQ keys for the next decade.",
            source: q(
              "\u201ceven after a billion-dollar quantum computer starts breaking thousands of ECC keys per year, there will still be many more broken PQ keys rescued by ECC+PQ for the next decade\u201d"
            ),
          },
          {
            kind: "con",
            text: "There are many ways ML-KEM can end up not being the eventual choice \u2014 the \u201csecond migration\u201d may happen regardless.",
            source: q(
              "\u201cthere are many ways that ML-KEM can end up not being the eventual choice\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "ECC is useless once a cryptographically relevant quantum computer exists; the ECC part of ECC+PQ then adds no real benefit.",
        source: q(
          "\u201cECC 'isn't doing much now and won't do anything at all, in just a few years'; 'hybrids are pointless' once there is a 'CRQC'; ECC+PQ 'will offer no real benefit over PQ once a CRQC exists'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "Eventual uselessness can't justify dropping ECC now: removing ECC from ECC+SIKE would have expanded the SIKE break into an immediate non-quantum compromise of every user.",
            source: q(
              "\u201ceven if ECC is eventually useless, this cannot justify avoiding ECC now; removing ECC from ECC+SIKE would have expanded the damage of the SIKE break by exposing ECC+SIKE users to immediate non-quantum attack\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "Lattices were fully vetted through a decade-long open NIST PQC process; no new cryptanalysis of ML-KEM has been offered.",
        source: q(
          "\u201clattices are very well studied and were 'fully vetted' through 'a full decade of entirely open, international analysis and debate'; 'ML-KEM was fully vetted through this process'; 'No new cryptanalyses have been offered'; 'The lattice candidates survived'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "Lattice candidates in that same process were broken (Compact LWE, HILA5's IND-CCA2 claim, Round2), and the surviving candidates have kept losing bits of security.",
            source: q(
              "\u201cactually, some of the lattice candidates in the NIST PQC process have already been broken (including Compact LWE, HILA5's IND-CCA2 claim, and Round2); furthermore, all of the remaining lattice candidates have lost many bits of security and are continuing to lose security\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "ML-KEM is easier to implement securely than its classical alternatives and will have exceedingly few bugs.",
        source: q(
          "\u201c'ML-KEM and ML-DSA are a lot easier to implement securely than their classical alternatives' and will have 'exceedingly few bugs'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "ML-KEM software has needed emergency security patches since December 2023: KyberSlash 1, then KyberSlash 2, then Clangover.",
            source: q(
              "\u201csince December 2023, Kyber/ML-KEM software has had emergency security patches for KyberSlash 1, then KyberSlash 2, then Clangover\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "ECC+PQ creates combinatorial software-engineering and testing complexity: every ECC option combined with every PQ option.",
        source: q(
          "\u201cthe problematic software engineering/testing complexity of combining each ECC option with each PQ option (e.g., ECC1+PQ1, ECC1+PQ2, \u2026); 'combinatorical explosion'; 'Support all of the schemes? Probably not feasible'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "The complexity is almost entirely inside the individual options; the combinations themselves are simple and easy to automate.",
            source: q(
              "\u201cno, the software engineering/testing complexity is almost entirely inside the individual options; the combinations are simple and easy to automate\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "Hybrid is cognitive dissonance: the quantum threat can't simultaneously be urgent and the PQ algorithms possibly broken.",
        source: q(
          "\u201cit is 'cognitive dissonance to simultaneously argue that the quantum threat requires immediate work, and yet we are also somehow uncertain of if the algorithms are totally broken. Both cannot be true at the same time'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "Demanding certainty is not competent risk management. ECC+PQ reduces damage from PQ breaks and from quantum attacks \u2014 it's wearing a seatbelt while trying to keep the car from crashing.",
            source: q(
              "\u201casking for certainty is not competent risk management; ECC+PQ sensibly tries to reduce damage from breaks of the PQ part and from quantum attacks; it's wearing your seatbelt and trying to make sure the car doesn't crash\u201d"
            ),
          },
        ],
      },
      {
        kind: "pro",
        text: "NSA includes ML-KEM-1024 in CNSA 2.0 and will use it itself \u2014 a serious endorsement; NSA can't plausibly hold an attack against it.",
        source: q(
          "\u201cNSA can't possibly have an attack against ML-KEM; NSA says they'll use ML-KEM; 'I regard the inclusion of ML-KEM-1024 in CNSA2 as a serious endorsement'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "NSA publicly said it would use DES while secretly rating it weak enough to break.",
            source: q(
              "\u201cNSA secretly said DES was weak enough to break, but publicly said they would use it\u201d"
            ),
          },
          {
            kind: "con",
            text: "If NSA holds an ML-KEM break, it will quietly use something else for its own data, whatever it claims publicly.",
            source: q(
              "\u201cif NSA has an ML-KEM break then for their own data they'll use something else, no matter what they claim publicly\u201d"
            ),
          },
        ],
      },
    ],
  },
  {
    kind: "answer",
    text: "Require hybrid (ECC+PQ): don't standardize solo-PQ key agreement in TLS.",
    source: q(
      "The opposing position throughout the chart: keep \u201cnormal ECC+PQ\u201d rather than \u201cweakening \u2026 to solo PQ\u201d."
    ),
    children: [
      {
        kind: "pro",
        text: "Half of proposed PQ cryptosystems have been mathematically broken. SIKE was publicly broken after SIKEp434 had been applied to tens of millions of user connections.",
        source: q(
          "\u201chalf of proposed PQ cryptosystems have been mathematically broken; for example, SIKE was publicly broken after SIKEp434 was applied to tens of millions of user connections\u201d \u2014 supporting \u201cweakening normal ECC+PQ to solo PQ creates security risks\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "\u201cWe will end up with secure implementations\u201d of PQ.",
            source: q("\u201cwe will end up with secure implementations\u201d of PQ"),
            children: [
              {
                kind: "con",
                text: "The same confidence was expressed for RSA-512, SIKE, and many other since-broken cryptosystems.",
                source: q(
                  "\u201cthe same argument applies to RSA-512, SIKE, and many other broken cryptosystems\u201d"
                ),
              },
            ],
          },
        ],
      },
      {
        kind: "pro",
        text: "ECC+PQ forces an attacker to break both ECC and the PQ scheme.",
        source: q("\u201cno, ECC+PQ forces attackers to break ECC and PQ\u201d"),
      },
      {
        kind: "pro",
        text: "Multiple national information-security authorities have set PQ/T hybrids as the standard.",
        source: q(
          "\u201cmultiple national information security authorities have set the use of PQ/T hybrids as the standard\u201d"
        ),
      },
      {
        kind: "pro",
        text: "Since ECC+PQ is deployed anyway, adding a solo-PQ option makes TLS more complicated by forcing more options.",
        source: q(
          "\u201csince we have ECC+PQ anyway, adding a PQ option makes TLS more complicated by forcing more options\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "A particular implementation can avoid implementing ECC entirely and thus become simpler.",
            source: q(
              "\u201cyes, but a particular implementation can avoid implementing ECC and can thus become simpler\u201d"
            ),
            children: [
              {
                kind: "con",
                text: "Such implementations fail to interoperate with already-deployed ECC+PQ and with the mandated ECC baseline for TLS.",
                source: q(
                  "\u201cno, those implementations will fail to interoperate with already-deployed ECC+PQ and with the mandated ECC baseline for TLS\u201d"
                ),
              },
            ],
          },
        ],
      },
      {
        kind: "con",
        text: "Nobody outside NSA will use solo PQ, so any ML-KEM breaks would impact no one else.",
        source: q(
          "\u201cnobody outside NSA will use this, so any breaks of ML-KEM will be 'not impacting anyone else'\u201d"
        ),
        children: [
          {
            kind: "con",
            text: "An RFC leads to usage far beyond NSA: applications pick whatever sounds most efficient, and several pro-solo arguments actively encourage broader solo-PQ usage.",
            source: q(
              "\u201cno, an RFC will lead to usage outside NSA; applications often choose whatever sounds like the most efficient solution; some of the pro arguments are actively encouraging broader usage of solo PQ\u201d"
            ),
          },
        ],
      },
    ],
  },
];
