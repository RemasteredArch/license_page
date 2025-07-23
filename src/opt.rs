#[derive(Clone, Eq, PartialEq, Hash, Debug)]
pub struct GetLicensesOpt {
    avoid_dev_deps: bool,
    avoid_build_deps: bool,
    avoid_proc_macros: bool,
}

impl GetLicensesOpt {
    pub fn new() -> Self {
        Self {
            avoid_dev_deps: false,
            avoid_build_deps: false,
            avoid_proc_macros: false,
        }
    }

    pub fn avoid_dev_deps(&self) -> bool {
        self.avoid_dev_deps
    }

    pub fn avoid_build_deps(&self) -> bool {
        self.avoid_build_deps
    }

    pub fn avoid_proc_macros(&self) -> bool {
        self.avoid_proc_macros
    }

    pub fn avoid_dev_deps_mut(&mut self) -> &mut bool {
        &mut self.avoid_dev_deps
    }

    pub fn avoid_build_deps_mut(&mut self) -> &mut bool {
        &mut self.avoid_build_deps
    }

    pub fn avoid_proc_macros_mut(&mut self) -> &mut bool {
        &mut self.avoid_proc_macros
    }
}

impl Default for GetLicensesOpt {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone, Eq, PartialEq, Hash, Debug, Default)]
pub struct ToMarkdownPageOpt {
    crate_licenses_preamble: Option<String>,
    preamble_section: Option<String>,
}

impl ToMarkdownPageOpt {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn crate_licenses_preamble(&self) -> Option<&str> {
        self.crate_licenses_preamble.as_deref()
    }

    pub fn crate_licenses_preamble_mut(&mut self) -> &mut Option<String> {
        &mut self.crate_licenses_preamble
    }

    pub fn preamble_section(&self) -> Option<&str> {
        self.preamble_section.as_deref()
    }

    pub fn preamble_section_mut(&mut self) -> &mut Option<String> {
        &mut self.preamble_section
    }
}
