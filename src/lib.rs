#![feature(stmt_expr_attributes)]

pub mod error;
pub mod oci_utils;
pub mod runtime_utils;
#[cfg(feature = "wasmedge")]
pub mod wasmedge;

#[cfg(feature = "wasmedge")]
#[macro_use]
extern crate lazy_static;
