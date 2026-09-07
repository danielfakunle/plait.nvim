# Mintlify guidance for documentation structure and agent-friendly content

Research for [PRO-126](https://linear.app/daniel-tf/issue/PRO-126/design-the-v01-documentation-journey-and-canonical-configuration), conducted 2026-09-06.

## Question and scope

What prescriptive guidance from Mintlify's first-party courses should inform the structure and canonical examples of a dedicated Plait documentation site?

This note covers both requested course overviews and every lesson listed in those courses. It translates the guidance into constraints and questions for Plait, whose primary reader is a Lua-comfortable owner of a Neovim configuration, whose public interface is a typed declaration-table API, and whose normal path must not require source inspection or provider knowledge. It does not choose Plait's final navigation, page inventory, or examples.

## Executive summary

Mintlify's central structural prescription is to organize documentation around a concrete reader's goals rather than product internals. Give each page one goal and one content type, put a quickstart first, separate task-oriented material from reference material, expose prerequisites before actions, introduce complete examples with placement and substitution guidance, keep recovery near likely failures, and end procedures with observable verification. Treat the structure as a hypothesis and improve it through search behavior, support questions, assistant conversations, and task testing.[^structure-overview][^readers][^content-types][^page-structure][^navigation][^measure]

For agents, Mintlify prescribes independently understandable, focused pages with specific metadata, standalone headings, consistent terminology, explicit cross-references, and complete runnable examples. Discovery should provide a descriptive, prioritized `llms.txt`; content-maintenance agents should receive audience, terminology, content-type, and style rules through `AGENTS.md` and/or `CLAUDE.md`. Agent readiness should be tested repeatedly against real questions for correctness, completeness, grounding, restraint, and usefulness.[^agent-overview][^agents-read][^write-agents][^control][^test]

For Plait, this makes the key documentation requirement stronger than merely publishing an API reference. The site must give a newcomer a short, verifiable path to a useful configuration while also offering focused task pages and a complete lookup surface for the typed declaration schema. Canonical examples must state where code belongs, include all required setup, use canonical Plait vocabulary, show expected effects or inspection results, and avoid making provider internals part of the normal explanation. These are implications of Mintlify's guidance and the ticket's stated product constraints, not a decision about the exact pages or examples.

## Prescriptive guidelines: documentation structure

### Define readers and goals first

- Define one primary reader for each documentation section in terms of role or experience, immediate goal, and assumed prior knowledge. "Developers" is not specific enough.[^readers]
- Make that reader definition persistent context for AI-assisted documentation edits rather than relying on each prompt to restate it.[^readers]
- Before writing a page, complete the sentence "After reading this page, the reader can ___." Split pages whose answer contains unrelated goals.[^page-structure]

### Assign one content type to each page

- Identify each page as a tutorial, how-to guide, reference, or explanation according to the reader's purpose: learn by doing, complete a task, look up facts, or understand a concept.[^content-types]
- Do not combine those jobs on one page. Tutorials are sequential and assume little; how-to guides give the shortest reliable path for a known goal; reference is complete and scannable; explanations provide context and relationships.[^content-types][^page-structure]
- Link between content types when a task needs conceptual background instead of embedding a substantial explanation in the task page.[^content-types]

### Make task pages scannable and executable

- Put required versions, software, values, access, permissions, and prior setup before instructions, with direct links to prerequisite procedures.[^page-structure]
- Use a meaningful heading hierarchy and headings that name the task, decision, or question. A reader should understand the page's progression by scanning headings alone.[^page-structure]
- Introduce every example by saying what it does, where it belongs, and what must be replaced. State the expected result afterward when it is not obvious.[^page-structure]
- Put task-specific warnings and recovery guidance near the action that can fail. Reserve broad troubleshooting pages for symptoms shared by multiple workflows.[^page-structure]
- End a procedure with an observable success check and only a meaningful next step.[^page-structure]

### Design navigation around user jobs

- Organize sections around what users are trying to accomplish, not features, implementation architecture, or the team's internal model.[^navigation]
- Put the quickstart first in the primary navigation group so a new user reaches a working state without first reading an overview.[^navigation]
- Keep doing and lookup modes distinct: tutorials and how-to guides should not be intermingled with reference material.[^navigation]
- Keep group labels short and goal-oriented. Use groups when pages share a purpose and likely reader journey.[^navigation]
- Use tabs only for meaningfully different audiences or use cases where one task remains within one tab. Do not use tabs merely to shorten a large sidebar.[^navigation]
- Use products only for genuinely separate product lines whose readers rarely cross between them, and anchors only for resources useful throughout the site.[^navigation]
- Test section labels without page content by asking an unfamiliar person where they would go for realistic tasks. Inventory page purpose, audience, type, traffic, and owner before reorganizing an existing site, and preserve moved URLs with redirects.[^navigation]

### Validate and maintain the structure

- Treat documentation structure as a hypothesis. Combine search queries, analytics, support questions, assistant conversations, and realistic task tests rather than treating page views as a sufficient quality measure.[^measure]
- Compare user language with site terminology; reader synonyms can improve titles, descriptions, or introductions without replacing the canonical product term.[^measure]
- Respond to evidence with the smallest testable structural change, such as renaming a label, improving metadata, adding a cross-link, splitting a mixed page, or removing competing stale content.[^measure]
- Manage documentation as version-controlled, reviewed content with previews. Ship documentation changes in the same change as the product behavior they describe.[^current]
- Automate broken-link, style or spelling, metadata, redirect, and secret checks where practical, while retaining human review.[^current][^security]
- Prefer targeted updates, but rewrite pages overwhelmed by caveats or obsolete workflows and delete inaccurate or duplicated material. Mintlify explicitly says wrong documentation is worse than no documentation.[^current]

## Prescriptive guidelines: agent-friendly content

### Write pages as independent retrieval units

- Treat each page as a standalone document and each important section as potentially retrieved without neighboring context. Define terms and acronyms on each page, repeat necessary prerequisites, and name dependencies explicitly.[^agents-read][^write-agents]
- Give every page a specific title and a concrete description that names the task and topics it covers. Titles such as "Advanced configuration" and generic descriptions provide poor retrieval signals.[^agents-read][^write-agents]
- Give every heading enough context to stand alone, keep each page focused on one topic or task, and provide focused how-to pages even when a multi-step quickstart also spans those tasks.[^agents-read][^write-agents]
- Pick one canonical name per concept. Record terminology rules for content-maintenance agents so synonyms do not drift into separate apparent concepts.[^agents-read][^write-agents]
- Replace context-dependent language such as "the above," "as mentioned," "this value," or an ambiguous "it" with the exact value, result, or named cross-reference.[^write-agents]

### Publish complete, safe examples

- Make code examples runnable as-is or mark and explain every substitution. Include required imports and initialization, and show expected output or effects when they are not obvious.[^write-agents]
- If a full example is too long, split it into sections that are themselves understandable rather than omitting necessary context.[^write-agents]
- Use unmistakable placeholders such as `YOUR_API_KEY`; never include working credentials, private hostnames, customer identifiers, production responses, or sensitive details in screenshots.[^security]

### Make authoritative content discoverable

- Supply an `llms.txt` with a blockquote product description, descriptive links, and the most important conceptual and common-task content before reference material. Exclude noisy, deprecated, internal, pre-release, and usually changelog or blog content from a curated version.[^control]
- Keep `llms-full.txt` inclusion decisions aligned with `llms.txt`. Exclusion is a retrieval preference, not access control; public URLs remain fetchable.[^control][^security]
- Prefer Markdown delivery because agents extract it more reliably than HTML. Mintlify automatically exposes page Markdown at `.md` URLs.[^control]
- Keep pages below the practical retrieval ceiling of roughly 50,000 characters. Avoid placing critical content in non-default tabs because agents typically see only the first tab, avoid client-only rendering, and preserve same-host redirects for moved pages.[^agents-read][^control]
- Use a machine-readable schema as the authority for structured API facts when one exists, and reserve prose for concepts, workflows, examples, and decisions. Avoid independently maintaining the same field definition in several places.[^control]

### Configure content-maintenance agents deliberately

- Put audience, canonical terminology, content-type rules, and recurring style constraints in `AGENTS.md` and/or `CLAUDE.md` so coding agents receive repository-wide context.[^control]
- Use the generated root `skill.md` unless agent workflows need a deliberate override. Publish custom `SKILL.md` packages when agents commonly need repeatable, task-specific procedures, inputs, and constraints; page discovery and question answering alone may not justify custom skills.[^control]
- Decide before configuring agent files which content matters most, what site-wide context pages cannot supply, and what agents should not surface.[^control]

### Evaluate behavior, including restraint

- Start with 5-10 real user questions in their original language, covering direct lookup, tasks, troubleshooting, cross-page synthesis, ambiguous requests, and unsupported requests.[^test]
- For every case, record required facts, supporting pages, prerequisites or warnings, prohibited claims, and whether the expected behavior is to answer, ask a follow-up question, or decline because the documentation does not cover it.[^test]
- Evaluate correctness, completeness, grounding, restraint, and usefulness rather than exact wording. A confident unsupported answer is a failed case.[^test]
- Run the same set before and after major releases and changes to navigation, terminology, `llms.txt`, agent instructions, or access controls. Diagnose whether failures came from retrieval, page focus, metadata, terminology, or competing outdated content.[^test][^ongoing]

### Preserve access boundaries and freshness

- Classify content as public, user-only, role-restricted, internal, or secret. Protect private material with authentication and authorization; navigation and `llms.txt` do not enforce access.[^security]
- State which public or private source is canonical for each audience, keep pre-release terms out of public answers, and test retrieval as each intended audience.[^security]
- Update affected pages before or alongside product releases; update canonical terminology and agent configuration when names or priorities change.[^ongoing]
- Review agent conversations monthly, audit terminology and high-traffic page self-containment quarterly, and rerun evaluations after major content or access changes. Review `llms.txt` whenever significant sections change.[^ongoing]

## Implications and constraints for the Plait decision

The following are deductions from Mintlify's guidance applied to the scope recorded in PRO-126. They constrain the decision without choosing the final information architecture or canonical examples.

1. **The documented audience needs an operational definition.** "Lua-comfortable Neovim configuration owner" should be expanded into the goal and assumed-knowledge dimensions Mintlify requires. In particular, the decision must state what Lua and Neovim knowledge may be assumed and which Plait, `vim.pack`, lifecycle, and provider concepts may not be assumed.[^readers]
2. **The journey and the schema lookup are different content contracts.** Learning the declaration-table API, completing capability tasks, understanding lifecycle and ownership, inspecting or repairing a configuration, and looking up field contracts should not collapse into one large setup page. The selected inventory should classify each intended page before deciding its placement.[^content-types][^page-structure]
3. **A first useful and observable configuration is a hard entry-path requirement.** Whatever example is selected as the quickstart must be first, complete, located in a named file or code location, explicit about prerequisites and substitutions, and followed by an observable success or inspection check.[^navigation][^page-structure][^write-agents]
4. **Navigation labels cannot require provider or internal-architecture knowledge.** Goal-oriented labels should let readers find common capability journeys, configuration changes, validation, and inspection without first knowing which plugin provides an effect or how Plait implements resolution.[^navigation]
5. **Canonical examples are executable product contracts.** Each example needs all required declarations and initialization, one canonical vocabulary, expected results, and nearby recovery for likely validation or lifecycle failures. Partial snippets are suitable only when their prerequisites and insertion point remain explicit.[^page-structure][^write-agents]
6. **The Plait-managed versus ordinary-Lua boundary needs explicit, retrievable treatment.** Because each page must stand alone, any task crossing that boundary must name which behavior Plait owns, what remains ordinary Lua, and the prerequisite or consequence of crossing it. A single explanation page may carry the conceptual model, but task pages must still state the local boundary and link to that explanation.[^content-types][^write-agents]
7. **Provider details should not leak into normal examples merely to make them concrete.** The ticket's no-provider-knowledge condition and Mintlify's goal-oriented structure imply capability-first titles, examples, and navigation. Any provider-specific escape-hatch material should be identifiable as a distinct advanced task or reference concern rather than an unstated prerequisite of the normal path.[^navigation][^write-agents]
8. **Typed declarations need one canonical source for field facts.** Mintlify warns against duplicating structured definitions. The decision should identify the authority from which field names, types, defaults, constraints, and reference output are maintained or generated, while prose teaches tasks and rationale.[^control]
9. **Validation and inspection should serve as proof, not only reference topics.** Canonical task examples should use observable validation or inspection outcomes where those are the product's way to prove success; separate focused pages can then cover repair and lookup without turning the quickstart into a troubleshooting compendium.[^page-structure][^test]
10. **The site must be usable from isolated page retrieval.** Every page that describes a declaration, capability, lifecycle phase, error, or ownership boundary needs enough local context for a search arrival or agent fetch. Cross-links can provide depth but cannot substitute for naming prerequisites and terms.[^agents-read][^write-agents]
11. **Agent discovery and maintenance are part of the site design.** The eventual site should plan for descriptive `.md` pages, prioritized `llms.txt` entries, and documentation-repository instructions that encode Plait's audience and canonical vocabulary. Whether Plait needs custom agent skills remains a separate option, not a baseline requirement.[^control]
12. **The chosen journey must be testable.** The documentation decision should leave room for task tests with unfamiliar Lua-comfortable Neovim users and an agent evaluation set that includes ordinary setup, lookup, validation failure, lifecycle or ownership ambiguity, provider-detail requests, and unsupported behavior.[^measure][^test]
13. **Canonical examples must change with the API.** Documentation and examples should ship with the product change they describe, with automated checks for links, metadata, terminology, and unsafe placeholders where practical.[^current][^ongoing][^security]

## Options and ambiguities Mintlify leaves open

Mintlify offers principles and alternatives rather than mandates in these areas:

- **Strictness of Diátaxis:** teams may apply the four content types strictly or loosely. Mintlify mandates clarity of page purpose more strongly than a particular taxonomy implementation.[^content-types]
- **Exact navigation tree:** goal-oriented organization and a first-position quickstart are prescribed, but the number and names of groups, whether guides and reference warrant tabs, and the complete page inventory depend on Plait's user jobs.[^navigation]
- **Tabs and products:** both are valid only under stated conditions; Mintlify does not require either. Plait must determine whether it has genuinely distinct audiences, use cases, or product lines.[^navigation]
- **Tutorial breadth:** quickstarts and tutorials may span several setup tasks even though focused task pages should exist for common individual needs.[^agents-read]
- **Terminology and reader language:** canonical terms should be consistent, but user synonyms may be included in metadata or introductory text to improve discovery.[^measure]
- **Generated versus custom `llms.txt`:** Mintlify's generated all-pages file is suitable for most sites; a curated file is optional when substantial content is low value or misleading for agents.[^control]
- **Generated versus custom skills:** generated `skill.md` may be sufficient for discovery and answering. Custom `SKILL.md` packages are optional for common agent-executed workflows.[^control]
- **`AGENTS.md` versus `CLAUDE.md`:** Mintlify describes overlapping roles and permits the same or simplified content in both. Tool coverage determines whether one or both are maintained.[^control]
- **Schema technology:** Mintlify recommends an OpenAPI or other machine-readable schema when a product has one, but does not prescribe a representation for a typed Lua declaration API or require generated reference pages.[^control]
- **Analytics and evaluation tooling:** the courses prescribe combined evidence and repeatable cases but not a vendor, harness, pass threshold, or automation level.[^measure][^test]
- **Maintenance cadence:** same-change product/docs updates are strongly prescribed; monthly, quarterly, and annual reviews are presented as a lightweight rhythm rather than a universal release policy.[^current][^ongoing]
- **Page length:** roughly 50,000 characters is presented as a practical agent-fetch truncation threshold, not an editorial target for normal pages.[^agents-read][^control]
- **Security architecture:** the courses require real access control for private content but leave authentication, authorization, and repository separation mechanisms to the site owner.[^security]

## Sources

All sources are first-party Mintlify course pages, accessed 2026-09-06. The Mintlify Learn index was used to verify the complete lesson lists.

[^structure-overview]: Mintlify Learn, [Structure docs that scale](https://learn.mintlify.com/courses/structure-docs/overview.md).
[^readers]: Mintlify Learn, [Understand your readers first](https://learn.mintlify.com/courses/structure-docs/understand-your-readers.md).
[^content-types]: Mintlify Learn, [Choose the right content type](https://learn.mintlify.com/courses/structure-docs/content-types.md).
[^page-structure]: Mintlify Learn, [Structure individual pages for scanning](https://learn.mintlify.com/courses/structure-docs/page-structure.md).
[^navigation]: Mintlify Learn, [Design navigation for your users (not your product)](https://learn.mintlify.com/courses/structure-docs/navigation-design.md).
[^measure]: Mintlify Learn, [Measure and improve findability](https://learn.mintlify.com/courses/structure-docs/measure-and-improve.md).
[^current]: Mintlify Learn, [Keep docs accurate as your product grows](https://learn.mintlify.com/courses/structure-docs/keeping-docs-current.md).
[^agent-overview]: Mintlify Learn, [Agent-friendly content](https://learn.mintlify.com/courses/agent-friendly-content/overview.md).
[^agents-read]: Mintlify Learn, [How agents read your content](https://learn.mintlify.com/courses/agent-friendly-content/how-agents-read-your-content.md).
[^write-agents]: Mintlify Learn, [Write content agents can use](https://learn.mintlify.com/courses/agent-friendly-content/write-for-agents.md).
[^control]: Mintlify Learn, [Control what agents see](https://learn.mintlify.com/courses/agent-friendly-content/control-what-agents-see.md).
[^test]: Mintlify Learn, [Test whether agents can use your content](https://learn.mintlify.com/courses/agent-friendly-content/test-agent-readiness.md).
[^security]: Mintlify Learn, [Protect private and sensitive information](https://learn.mintlify.com/courses/agent-friendly-content/security-and-access.md).
[^ongoing]: Mintlify Learn, [Keep content agent-friendly over time](https://learn.mintlify.com/courses/agent-friendly-content/ongoing-maintenance.md).

Additional index used to verify course coverage: <https://learn.mintlify.com/llms.txt>.
