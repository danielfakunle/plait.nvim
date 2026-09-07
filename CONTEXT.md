# Plait

Plait describes Neovim configurations in terms of active capabilities and the integrations that realize them.

## Language

**Configuration owner**:
A person comfortable writing Lua who wants to own their Neovim configuration while delegating recurring plugin-integration work.
_Avoid_: End user, distro user, framework builder

**Neovim configuration**:
The configuration owner's complete editor configuration, including Plait-managed declarations and ordinary Lua outside Plait.
_Avoid_: Plait configuration

**Plait configuration**:
The declarative input through which a configuration owner selects and customizes what Plait manages.
_Avoid_: Neovim configuration, resolved configuration

**Author journey**:
A capability-independent scenario in which a configuration owner adopts, composes, customizes, diagnoses, inspects, or deliberately escapes Plait-managed configuration.
_Avoid_: Feature walkthrough, implementation task

**Canonical configuration fixture**:
A complete, executable Plait configuration that is the authority behind documentation examples and release-validation scenarios.
_Avoid_: Untested snippet, illustrative pseudocode

**Managed effect**:
An observable change to Neovim or its providers that results from the Plait configuration and remains Plait's responsibility.
_Avoid_: Arbitrary Lua effect, provider internal

**Effective plan**:
The deterministic, validated account of the managed effects Plait will apply for a Plait configuration, including their provenance and ordering.
_Avoid_: Plait configuration, runtime state

**Normal authoring path**:
Selecting modules and customizing supported capability-level behavior without relying on provider-specific knowledge.
_Avoid_: Provider configuration, arbitrary mutation

**Configuration point**:
A named, supported location in the Plait configuration where a module or configuration owner may contribute a value or behavior.
_Avoid_: Provider option, arbitrary table path

**Provenance**:
The explanation connecting a managed effect or effective value to the owner declaration, module, capability, and provider contributions that produced it.
_Avoid_: Execution trace, debug log

**Capability**:
A user-meaningful editor outcome activated through an owner-selected module. Dependencies constrain which selected modules form a valid configuration; they never activate capabilities implicitly. A capability's realization may involve one or more plugins, native settings, or external tools.
_Avoid_: Feature, plugin

**Provider**:
A plugin, native Neovim behavior, or external tool that directly participates in realizing a capability. A capability integration may coordinate multiple providers, and a provider may participate in multiple capability integrations.
_Avoid_: Capability, module

**Provider escape hatch**:
An explicit boundary where a configuration owner supplies opaque provider-specific options that Plait does not type or validate, except to protect integration settings owned by Plait.
_Avoid_: Capability configuration, provider wrapper

**Package requirement**:
A declaration that a capability integration needs a plugin package, including its canonical identity, source, version constraint, provenance, and responsible capability. Plait translates package requirements into package-manager operations without exposing the package manager's interface as module vocabulary.
_Avoid_: Plugin specification, provider configuration

**Package synchronization**:
An explicit, configuration-owner-authorized operation that reconciles installed package checkouts and the shared `vim.pack` lockfile with Plait's effective package requirements.
_Avoid_: Automatic update, package activation

**Compatibility manifest**:
The versioned, executable declaration that binds a Plait release to its supported Neovim and platform matrix, qualified provider revisions, external-tool constraints, and provider guard metadata.
_Avoid_: Release-please manifest, lockfile, release notes

**Provider application phase**:
A lifecycle boundary at which a responsible capability applies its fully assembled provider configuration. In v0.1, provider application occurs during the configuration owner's initialization, after package activation and before normal plugin entrypoints are sourced.
_Avoid_: Module order, package installation order

**Capability integration**:
The coherent set of provider choices, dependencies, settings, and interactions through which Plait realizes a capability.
_Avoid_: Plugin configuration, plugin stack

**Capability contract**:
The supported managed effects, configuration points, defaults, contributions, interactions, and ownership boundary through which Plait promises a capability's outcome. It describes normal authoring behavior without duplicating a provider's interface.
_Avoid_: Provider configuration, module implementation

**Capability facade**:
Plait's provider-independent interface to common user intentions and status that belong to a capability.
_Avoid_: Provider wrapper

**Capability action**:
A provider-independent operation exposed by a capability facade and shared by its Lua, command, and mapping entry points.
_Avoid_: Provider command

**Responsible capability**:
The single capability accountable for applying and explaining a managed effect, including effects assembled from contributions made by other modules or capabilities.
_Avoid_: Sole contributor, provider owner

**Tool requirement**:
A declaration that a capability integration needs an external executable, including the compatible version and who is responsible for supplying it.
_Avoid_: Plugin dependency, automatic installation request

**Tool ownership policy**:
The rule that determines which environment or tool provider may supply an external executable and which one owns its installation and updates.
_Avoid_: Executable search result, provider configuration

**Module**:
A named, reusable compositional unit that contributes declarations toward one or more capability integrations.
_Avoid_: Capability, provider, plugin

**Dependency**:
A capability that must be activated through an explicitly selected module for another module's contributions to be valid. A dependency validates and orders selected modules; it does not activate a capability.
_Avoid_: Provider, hard-coded module dependency

**Override**:
A declaration that intentionally supersedes an existing declaration at a supported Plait configuration point while leaving Plait responsible for the result.
_Avoid_: Extension, conflict

**Extension**:
A contribution of new declarations or behavior without superseding an existing declaration.
_Avoid_: Override

**Conflict**:
Incompatible module contributions to the same configuration point where neither deliberately supersedes the other.
_Avoid_: Override

**Release gate**:
A mandatory automated or human acceptance criterion that must pass before a change is merged or a Plait release is published.
_Avoid_: Advisory check

**Release qualification**:
The recorded evidence that a release candidate satisfies every release gate across the supported compatibility matrix and author journeys.
_Avoid_: Version declaration, inferred compatibility
