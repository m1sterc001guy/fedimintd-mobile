#![allow(unexpected_cfgs)]

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

use std::{fs::OpenOptions, io, os::fd::AsRawFd, path::Path};

use fedimint_core::{anyhow, fedimint_build_code_version_env};
use flutter_rust_bridge::frb;

pub fn redirect_output(log_file_path: &Path) -> io::Result<()> {
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_file_path)?;

    let fd = file.as_raw_fd();

    // Duplicate file descriptor to stdout (fd 1) and stderr (fd 2)
    unsafe {
        libc::dup2(fd, libc::STDOUT_FILENO);
        libc::dup2(fd, libc::STDERR_FILENO);
    }

    // Optional: If you're using `println!`, flush stdout explicitly sometimes
    println!("Redirected stdout and stderr to {:?}", log_file_path);
    Ok(())
}

#[frb]
pub async fn start_fedimintd(path: String) -> anyhow::Result<()> {
    let fedimintd_dir = Path::new(&path).join("fedimintd_mobile");

    // Create the directory if it doesn't exist
    std::fs::create_dir_all(&fedimintd_dir)?;

    let log_path = fedimintd_dir.join("fedimintd.txt");
    redirect_output(&log_path)?;
    println!("Starting fedimintd...");
    std::env::set_var("FM_ENABLE_IROH", "true");
    std::env::set_var("FM_DATA_DIR", fedimintd_dir);
    std::env::set_var("FM_BITCOIN_NETWORK", "bitcoin");
    std::env::set_var("FM_ESPLORA_URL", "https://mempool.space/api");
    // Not sure if this is currently necessary
    std::env::set_var("FM_BIND_UI", "0.0.0.0:8175");
    fedimintd::run(
        fedimintd::default_modules,
        fedimint_build_code_version_env!(),
        None,
    )
    .await
}