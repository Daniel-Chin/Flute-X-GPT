#ifndef FILE_wifi_SEEN
#define FILE_wifi_SEEN

#define NETIF_DESC_STA "music x flute NETIF STA"
#define WIFI_CONN_MAX_RETRY 6
#define ESP_WIFI_SCAN_AUTH_MODE_THRESHOLD WIFI_AUTH_WPA2_PSK
#define ESP_WIFI_SAE_MODE WPA3_SAE_PWE_BOTH
#define CONFIG_ESP_WIFI_PW_ID ""
#define EXAMPLE_H2E_IDENTIFIER CONFIG_ESP_WIFI_PW_ID

void wifi_init_sta(void);
char* getLocalIP(void);

#endif
