#![warn(clippy::nursery, clippy::pedantic)]

use std::collections::BTreeSet;

use license_display::CrateMarkdown;
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

    fn text(&self) -> &'static str {
        match self {
            Self::License(license_id) => license_id.text(),
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
    let crates = license_display::get_crates(location.as_str());

    let by_license = crates.by_license();

    // ```rust
    // for (count, license, crates) in by_license {
    //     println!(
    //         "{license} ({count}): {}",
    //         crates
    //             .iter()
    //             .map(|license_display::Crate { name, .. }| name.as_str())
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
        println!("\n## {}\n", license_display::escape_markdown(id.title()));

        for line in id.text().lines() {
            println!("> {line}");
        }

        println!();
    }
}
