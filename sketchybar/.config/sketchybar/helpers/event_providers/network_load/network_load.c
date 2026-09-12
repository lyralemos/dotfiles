#include <unistd.h>
#include <signal.h>
#include "network.h"
#include "../sketchybar.h"

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 4 || (sscanf(argv[3], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<interface>\" \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);

  // Setup signal handlers and atexit cleanup for child processes
  atexit(network_cleanup);
  signal(SIGINT, network_sig_handler);
  signal(SIGTERM, network_sig_handler);
  signal(SIGHUP, network_sig_handler);

  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[2]);
  sketchybar(event_message);

  int master, slave;
  bool use_nettop = false;

  if (openpty(&master, &slave, NULL, NULL, NULL) != -1) {
    g_master_fd = master;
    g_child_pid = fork();
    if (g_child_pid == 0) {
      close(master);
      dup2(slave, STDOUT_FILENO);
      dup2(slave, STDERR_FILENO);
      close(slave);

      int freq_sec = (int)update_freq;
      if (freq_sec < 1) freq_sec = 1;
      char freq_str[16];
      snprintf(freq_str, sizeof(freq_str), "%d", freq_sec);

      char* args[] = {
        "nettop",
        "-t", "external",
        "-P",
        "-L", "0",
        "-s", freq_str,
        "-n",
        "-x",
        "-d",
        "-J", "bytes_in,bytes_out",
        NULL
      };
      execvp("nettop", args);
      _exit(1);
    } else if (g_child_pid > 0) {
      close(slave);
      use_nettop = true;
    } else {
      close(master);
      close(slave);
      g_master_fd = -1;
    }
  }

  char trigger_message[512];

  if (use_nettop) {
    FILE* stream = fdopen(g_master_fd, "r");
    char line[512];
    int64_t sample_in = 0, sample_out = 0;
    int sample_count = 0;

    while (stream && fgets(line, sizeof(line), stream)) {
      if (strstr(line, "bytes_in,bytes_out")) {
        if (sample_count > 0) {
          char up_str[32], down_str[32];
          double down_rate = (double)sample_in / update_freq;
          double up_rate = (double)sample_out / update_freq;
          format_rate(up_rate, up_str, sizeof(up_str));
          format_rate(down_rate, down_str, sizeof(down_str));

          snprintf(trigger_message,
                   sizeof(trigger_message),
                   "--trigger '%s' upload='%s' download='%s'",
                   argv[2],
                   up_str,
                   down_str);
          sketchybar(trigger_message);
        }
        sample_count++;
        sample_in = 0;
        sample_out = 0;
        continue;
      }

      char* p = strchr(line, ',');
      if (p) {
        int64_t bin = 0, bout = 0;
        if (sscanf(p + 1, "%lld,%lld", &bin, &bout) == 2) {
          if (bin > 0) sample_in += bin;
          if (bout > 0) sample_out += bout;
        }
      }
    }
  }

  // Fallback to sysctl if nettop failed or exited
  struct sysctl_net snet;
  sysctl_net_init(&snet, argv[1]);

  for (;;) {
    usleep((useconds_t)(update_freq * 1000000));
    double rate_down = 0, rate_up = 0;
    sysctl_net_update(&snet, &rate_down, &rate_up);
    char up_str[32], down_str[32];
    format_rate(rate_up, up_str, sizeof(up_str));
    format_rate(rate_down, down_str, sizeof(down_str));

    snprintf(trigger_message,
             sizeof(trigger_message),
             "--trigger '%s' upload='%s' download='%s'",
             argv[2],
             up_str,
             down_str);
    sketchybar(trigger_message);
  }

  return 0;
}
