einfo "Removing package ${pkg}"
remove_pkg "${CATEGORY}/${PF}" 1 || die "unmerge failed!"
