#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <signal.h>
#include <util.h>
#include <sys/wait.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_mib.h>

static inline void format_rate(double bytes_per_sec, char* out, size_t out_len) {
  if (bytes_per_sec < 0.5) {
    snprintf(out, out_len, "000 Bps");
    return;
  }
  if (bytes_per_sec < 1000.0) {
    snprintf(out, out_len, "%03.0f Bps", bytes_per_sec);
  } else if (bytes_per_sec < 1000000.0) {
    snprintf(out, out_len, "%03.0fKBps", bytes_per_sec / 1000.0);
  } else if (bytes_per_sec < 1000000000.0) {
    snprintf(out, out_len, "%03.0fMBps", bytes_per_sec / 1000000.0);
  } else {
    snprintf(out, out_len, "%03.0fGBps", bytes_per_sec / 1000000000.0);
  }
}

// Global child PID for cleanup on exit/signals
static pid_t g_child_pid = 0;
static int g_master_fd = -1;

static inline void network_cleanup(void) {
  if (g_child_pid > 0) {
    kill(g_child_pid, SIGTERM);
    waitpid(g_child_pid, NULL, WNOHANG);
    g_child_pid = 0;
  }
  if (g_master_fd >= 0) {
    close(g_master_fd);
    g_master_fd = -1;
  }
}

static inline void network_sig_handler(int sig) {
  (void)sig;
  network_cleanup();
  exit(0);
}

// Fallback sysctl implementation (with macOS bug fixes)
struct sysctl_net {
  uint32_t row;
  struct ifmibdata data;
  struct timeval tv_nm1, tv_n, tv_delta;
};

static inline void ifdata(uint32_t net_row, struct ifmibdata* data) {
  size_t size = sizeof(struct ifmibdata);
  int32_t data_option[] = { CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, (int32_t)net_row, IFDATA_GENERAL };
  sysctl(data_option, 6, data, &size, NULL, 0);
}

static inline bool sysctl_net_init(struct sysctl_net* net, const char* ifname) {
  memset(net, 0, sizeof(struct sysctl_net));
  int count_option[] = { CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT };
  uint32_t interface_count = 0;
  size_t size = sizeof(uint32_t);
  if (sysctl(count_option, 5, &interface_count, &size, NULL, 0) != 0) return false;

  for (uint32_t i = 1; i <= interface_count; i++) {
    ifdata(i, &net->data);
    if (strcmp(net->data.ifmd_name, ifname) == 0) {
      net->row = i;
      gettimeofday(&net->tv_nm1, NULL);
      return true;
    }
  }
  return false;
}

static inline void sysctl_net_update(struct sysctl_net* net, double* rate_down, double* rate_up) {
  gettimeofday(&net->tv_n, NULL);
  timersub(&net->tv_n, &net->tv_nm1, &net->tv_delta);
  net->tv_nm1 = net->tv_n;

  uint64_t ibytes_nm1 = net->data.ifmd_data.ifi_ibytes;
  uint64_t obytes_nm1 = net->data.ifmd_data.ifi_obytes;
  ifdata(net->row, &net->data);

  double time_scale = (net->tv_delta.tv_sec + 1e-6 * net->tv_delta.tv_usec);
  if (time_scale < 1e-6) time_scale = 1.0;

  int64_t d_ibytes = (int64_t)(net->data.ifmd_data.ifi_ibytes - ibytes_nm1);
  int64_t d_obytes = (int64_t)(net->data.ifmd_data.ifi_obytes - obytes_nm1);
  if (d_ibytes < 0) d_ibytes = 0;
  if (d_obytes < 0) d_obytes = 0;

  *rate_down = (double)d_ibytes / time_scale;
  *rate_up = (double)d_obytes / time_scale;
}
