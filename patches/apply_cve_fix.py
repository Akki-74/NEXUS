#!/usr/bin/env python3
"""
Applies or reverts the CVE-2022-32250 fix on Linux 5.15.40 source file:
  net/netfilter/nf_tables_api.c
"""
import sys
import os

def apply_patch(target_file, reverse=False):
    if not os.path.exists(target_file):
        print(f"Error: {target_file} not found")
        sys.exit(1)

    with open(target_file, "r") as f:
        content = f.read()

    # Targets in Linux 5.15.40
    target_unpatched_1 = """\terr = nf_tables_expr_parse(ctx, nla, &expr_info);
\tif (err < 0)
\t\tgoto err1;

\terr = -ENOMEM;"""

    target_patched_1 = """\terr = nf_tables_expr_parse(ctx, nla, &expr_info);
\tif (err < 0)
\t\tgoto err1;

\terr = -EOPNOTSUPP;
\tif (!(expr_info.ops->type->flags & NFT_EXPR_STATEFUL))
\t\tgoto err2;

\terr = -ENOMEM;"""

    target_unpatched_2 = """\texpr = nft_expr_init(ctx, attr);
\tif (IS_ERR(expr))
\t\treturn expr;

\terr = -EOPNOTSUPP;
\tif (!(expr->ops->type->flags & NFT_EXPR_STATEFUL))
\t\tgoto err_set_elem_expr;

\tif (expr->ops->type->flags & NFT_EXPR_GC) {"""

    target_patched_2 = """\texpr = nft_expr_init(ctx, attr);
\tif (IS_ERR(expr))
\t\treturn expr;

\tif (expr->ops->type->flags & NFT_EXPR_GC) {"""

    if not reverse:
        if target_patched_1 in content:
            print("[*] CVE-2022-32250 patch already applied.")
            return
        if target_unpatched_1 not in content or target_unpatched_2 not in content:
            print("[-] Error: Unpatched pattern not found in target file.")
            sys.exit(1)
        content = content.replace(target_unpatched_1, target_patched_1, 1)
        content = content.replace(target_unpatched_2, target_patched_2, 1)
        print("[+] Applied CVE-2022-32250 fix to nf_tables_api.c")
    else:
        if target_unpatched_1 in content:
            print("[*] Already in unpatched state.")
            return
        content = content.replace(target_patched_1, target_unpatched_1, 1)
        content = content.replace(target_patched_2, target_unpatched_2, 1)
        print("[+] Reverted CVE-2022-32250 fix in nf_tables_api.c")

    with open(target_file, "w") as f:
        f.write(content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: apply_cve_fix.py <path_to_nf_tables_api.c> [--reverse]")
        sys.exit(1)
    target = sys.argv[1]
    is_reverse = "--reverse" in sys.argv
    apply_patch(target, is_reverse)
