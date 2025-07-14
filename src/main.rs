// SPDX-License-Identifier: MPL-2.0
//
// Copyright © 2025 RemasteredArch
//
// This Source Code Form is subject to the terms of the Mozilla Public License, version 2.0. If a
// copy of the Mozilla Public License was not distributed with this file, You can obtain one at
// <https://mozilla.org/MPL/2.0/>.

#![warn(clippy::nursery, clippy::pedantic)]

use std::collections::BTreeSet;

use license_page::CrateMarkdown;
use spdx::{ExceptionId, LicenseId};

#[derive(PartialEq, Eq, PartialOrd, Ord)]
enum LicensePart {
    License(LicenseId),
    Exception(ExceptionId),
}

impl LicensePart {
    fn title(&self) -> String {
        match self {
            Self::License(license_id) => license_id.full_name.to_string(),
            Self::Exception(exception_id) => format!("`{}`", exception_id.name),
        }
    }

    /// It will first check if a license is present in
    /// [the licenses from `choosealicense.com`](https://github.com/github/choosealicense.com/tree/gh-pages/_licenses)
    /// (which provides hand-wrapped copies license texts), otherwise it will pull the text from
    /// [`spdx`] (which themselves are drawn from
    /// [SPDX's plain text license dumps](https://github.com/spdx/license-list-data/tree/main/text)).
    /// Only licenses and exceptions from the [SPDX License List](https://spdx.org/licenses) are
    /// supported.
    fn text(&self) -> &'static str {
        match self {
            Self::License(license_id) => {
                // Sorts by lowercase byte value, which should hopefully match that of
                // `harvest_licenses.sh`.
                license_page::LICENSE_TEXTS
                    .binary_search_by_key(&license_id.name.to_lowercase().as_str(), |(id, _)| id)
                    .map_or_else(
                        |_| license_id.text(),
                        |index| license_page::LICENSE_TEXTS[index].1,
                    )
            }
            Self::Exception(exception_id) => exception_id.text(),
        }
    }
}

impl From<LicenseId> for LicensePart {
    fn from(value: LicenseId) -> Self {
        Self::License(value)
    }
}

impl From<ExceptionId> for LicensePart {
    fn from(value: ExceptionId) -> Self {
        Self::Exception(value)
    }
}

fn main() {
    let location = std::env::args().nth(1).unwrap_or_else(|| ".".to_string());
    let crates = license_page::get_crates(location.as_str());

    let by_license = crates.by_license();

    // ```rust
    // for (count, license, crates) in by_license {
    //     println!(
    //         "{license} ({count}): {}",
    //         crates
    //             .iter()
    //             .map(|license_page::Crate { name, .. }| name.as_str())
    //             .collect::<Vec<_>>()
    //             .join(", ")
    //     );
    // }
    // ```

    println!("# Crate Licenses");
    let mut ids_to_print = BTreeSet::<LicensePart>::new();

    for (count, license_expression, crates) in by_license {
        println!(
            "\n## `{license_expression}`\n\nUsed by {count} {}:\n",
            if count == 1 { "crate" } else { "crates" }
        );

        for CrateMarkdown {
            name,
            version,
            authors,
            repository,
            ..
        } in crates.iter().map(|&c| c.clone().into_markdown())
        {
            println!("- {name} {version}\n  - Repository: {repository}");
            match authors.len() {
                0 => (),
                1 => {
                    println!("  - Primary author: {}", authors[0]);
                }
                _ => {
                    println!("  - Primary authors:");
                    for author in authors {
                        println!("    - {author}");
                    }
                }
            }
        }

        for req in license_expression.requirements() {
            let spdx::LicenseReq {
                license: license_item,
                exception,
            } = &req.req;

            let license_id = match license_item {
                spdx::LicenseItem::Spdx { id, .. } => id,
                spdx::LicenseItem::Other { .. } => {
                    panic!("Received non-SPDX item in license `{license_expression}`")
                }
            };

            ids_to_print.insert((*license_id).into());
            if let Some(exception_id) = exception {
                ids_to_print.insert((*exception_id).into());
            }
        }
    }

    println!("\n# License and Exception Full Texts");

    for id in ids_to_print {
        println!(
            "\n## {}\n\n```text\n{}```",
            license_page::escape_markdown(id.title()),
            id.text()
        );
    }
}
