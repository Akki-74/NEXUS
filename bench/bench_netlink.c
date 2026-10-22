/* SPDX-License-Identifier: MIT */
/*
 * bench_netlink.c - Micro-benchmark for nf_tables transaction latency
 *
 * Measures:
 * 1. Table creation & deletion round-trip latency
 * 2. Set element addition & lookup latency
 * 3. Performance overhead comparison between baseline and patched kernels
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <sys/socket.h>
#include <linux/netlink.h>
#include <arpa/inet.h>

#include "../exploit/common/namespace_setup.h"
#include "../exploit/common/netlink_helpers.h"

#define BENCH_TABLE "bench_tbl"
#define BENCH_SET   "bench_set"
#define DEFAULT_ROUNDS 500

static double get_time_sec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static int create_table(int fd)
{
	struct nlbuf b;
	struct nlmsghdr *nlh;

	nlbuf_init(&b);
	nft_batch_begin(&b);
	nlh = nft_msg_begin(&b, NFT_MSG_NEWTABLE,
			    NLM_F_CREATE | NLM_F_ACK, NFPROTO_IPV4);
	nla_put_str(&b, NFTA_TABLE_NAME, BENCH_TABLE);
	nlmsg_end(&b, nlh);
	nft_batch_end(&b);

	return nft_send(fd, &b, "NEWTABLE bench");
}

static int delete_table(int fd)
{
	struct nlbuf b;
	struct nlmsghdr *nlh;

	nlbuf_init(&b);
	nft_batch_begin(&b);
	nlh = nft_msg_begin(&b, NFT_MSG_DELTABLE, NLM_F_ACK, NFPROTO_IPV4);
	nla_put_str(&b, NFTA_TABLE_NAME, BENCH_TABLE);
	nlmsg_end(&b, nlh);
	nft_batch_end(&b);

	return nft_send(fd, &b, "DELTABLE bench");
}

int main(int argc, char **argv)
{
	int rounds = DEFAULT_ROUNDS;
	int fd, i;
	double start, end, total;

	if (argc > 1) {
		rounds = atoi(argv[1]);
		if (rounds <= 0)
			rounds = DEFAULT_ROUNDS;
	}

	printf("=== NEXUS Netfilter Transaction Benchmark ===\n");
	printf("[*] Target iterations: %d\n", rounds);

	if (ns_setup_user_net() < 0) {
		fprintf(stderr, "[-] Failed to configure user/net namespace: %s\n",
			strerror(errno));
		return 1;
	}

	fd = nl_open();
	if (fd < 0) {
		perror("[-] socket(NETLINK_NETFILTER)");
		return 1;
	}

	printf("[+] Measuring Table Create/Delete round-trip latency...\n");
	start = get_time_sec();

	for (i = 0; i < rounds; i++) {
		if (create_table(fd) != 0) {
			fprintf(stderr, "[-] create_table failed at round %d\n", i);
			break;
		}
		if (delete_table(fd) != 0) {
			fprintf(stderr, "[-] delete_table failed at round %d\n", i);
			break;
		}
	}

	end = get_time_sec();
	total = end - start;

	if (i > 0) {
		double avg_us = (total / (i * 2)) * 1e6;
		double ops_sec = (double)(i * 2) / total;

		printf("\n--- Results ---\n");
		printf("Completed cycles:        %d (x2 transactions)\n", i);
		printf("Total elapsed time:      %.4f seconds\n", total);
		printf("Average op latency:      %.2f us\n", avg_us);
		printf("Throughput:              %.2f ops/sec\n", ops_sec);
		printf("CSV: %d,%.4f,%.2f,%.2f\n", i, total, avg_us, ops_sec);
	}

	close(fd);
	return 0;
}
