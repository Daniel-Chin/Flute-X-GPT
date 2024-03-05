#include "wifi.h"

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"

#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"

#include "kit.h"
#include "shared.h"
#include "env.h"
#include "comm.h"
#include "wifi.h"
#include "print_and_send_log.h"
#include "secrets.h"
#include "priorities.h"

static CommCallbackRecv_t onRecv;
static bool ready_to_send = false;

static int udp_sock;
static int tcp_sock;
static struct sockaddr* udp_remote_addr;
static socklen_t udp_remote_addr_len;

static void onHostDisconnect(void) {
    esp_restart();
}

static int packetSizeOf(char header) {
    // compiler will (hopefully) optimize the switch into a lookup table
    switch (header) {
        case 'H':
        case 'B':
        case 'W':
        case '\r':
            return 1;
        case 'C':
        case 'M':
        case 'A':
        case 'L':
            return 2;
        case 'P':
        case 'O':
            return 3;
        case 'N':
            return 12;
        default:
            char msg[38 * 2];
            ellipses(msg, sizeof(msg), snprintf(
                msg, sizeof(msg), "packetSizeOf() unknown header chr(%d)", (int) header
            ));
            printAndSendError(msg);
            abort();
    }
}

static inline void checkForConnectionReset(void) {
    if (errno == ECONNRESET) {
        ESP_LOGE(PROJECT_TAG, "checkForConnectionReset(): Host disconnected.");
        onHostDisconnect();
    }
}

static void initUDP(void) {
    static struct sockaddr_in remote_addr;
    remote_addr.sin_addr.s_addr = inet_addr(HOST_IP_ADDR);
    remote_addr.sin_family = AF_INET;
    remote_addr.sin_port = htons(UDP_PORT);
    udp_remote_addr = (struct sockaddr*) &remote_addr;
    udp_remote_addr_len = sizeof(*udp_remote_addr);

    static struct sockaddr_in local_addr;
    local_addr.sin_addr.s_addr = inet_addr(getLocalIP());
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(UDP_PORT);

    udp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (udp_sock < 0) {
        ESP_LOGE(PROJECT_TAG, "Unable to create UDP socket: errno %d", errno);
        abort();
    }
    struct sockaddr* udp_local_addr = (struct sockaddr*) &local_addr;
    bind(
        udp_sock, udp_local_addr, sizeof(*udp_local_addr)
    );
    ESP_LOGI(
        PROJECT_TAG, 
        "UDP socket created, bound to %s:%d, pointing at %s:%d", 
        getLocalIP(), UDP_PORT, HOST_IP_ADDR, UDP_PORT
    );
}

static void udpReceiver(void* _) {
    uint8_t rx_buffer[RX_BUFFER_SIZE];

    // Large enough for both IPv4 or IPv6
    struct sockaddr_storage source_addr;
    socklen_t socklen = sizeof(source_addr);

    while (1) {
        int len = recvfrom(
            udp_sock, rx_buffer, RX_BUFFER_SIZE, 0, 
            (struct sockaddr *) &source_addr, &socklen
        );
        if (len < 0) {
            // Error occurred during receiving
            char msg[24 * 2];
            ellipses(msg, sizeof(msg), snprintf(
                msg, sizeof(msg), "UDP recvfrom() errno %d", errno
            ));
            printAndSendError(msg);
            abort();
        }

        onRecv(len, rx_buffer, &source_addr);
    }
}

static void initTCP(void) {
    struct sockaddr_in remote_addr;
    inet_pton(AF_INET, HOST_IP_ADDR, &remote_addr.sin_addr);
    remote_addr.sin_family = AF_INET;
    remote_addr.sin_port = htons(HOST_TCP_PORT);

    while (1) { // auto-retry connecting
        tcp_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
        if (tcp_sock < 0) {
            ESP_LOGE(PROJECT_TAG, "Unable to create TCP socket: errno %d", errno);
            abort();
        }

        ESP_LOGI(
            PROJECT_TAG, "TCP socket connecting to %s:%d...", 
            HOST_IP_ADDR, HOST_TCP_PORT
        );
        int err = connect(
            tcp_sock, (struct sockaddr *) &remote_addr, 
            sizeof(remote_addr)
        );
        if (err != 0) {
            ESP_LOGW(PROJECT_TAG, "Socket unable to connect: errno %d. Gonna retry.", errno);
            shutdown(tcp_sock, 0);
            close(tcp_sock);
            delayTaskMs((int) 1e3);
            continue;
        }

        ESP_LOGI(PROJECT_TAG, "TCP connection established.");
        break;
    }
}

static int caughtRecv(void* buffer, size_t length, int flags) {
    int len = recv(tcp_sock, buffer, length, flags);
    if (len == 0) {
        ESP_LOGE(PROJECT_TAG, "caughtRecv(): Host disconnected.");
        onHostDisconnect();
    } else if (len < 0) {
        // Error occurred during receiving
        checkForConnectionReset();
        char msg[20 * 2];
        ellipses(msg, sizeof(msg), snprintf(
            msg, sizeof(msg), "TCP recv() errno %d", errno
        ));
        printAndSendError(msg);
        abort();
    }
    return len;
}

static void tcpReceiver(void* _) {
    uint8_t rx_buffer[RX_BUFFER_SIZE];

    while (1) {
        (void) caughtRecv(rx_buffer, 1, MSG_PEEK);
        char header = rx_buffer[0];
        int packet_size = packetSizeOf(header);
        int len = caughtRecv(rx_buffer, packet_size, MSG_WAITALL);
        onRecv(len, rx_buffer, NULL);
        #ifndef MUSX_DEBUG
            I am using syntax error to denote undefined macro here!
        #endif
        #if MUSX_DEBUG == 1
            assert(len == packet_size);
        #endif
    }
}

static inline void commSend(
    bool is_udp_not_tcp, uint8_t const * payload, size_t size
) {
    if (! ready_to_send) {
        ESP_LOGE(PROJECT_TAG, "commSend() when ready_to_send == false");
        abort();
    }

    int n_sent;
    if (is_udp_not_tcp) {
        n_sent = sendto(
            udp_sock, payload, size, 0, 
            udp_remote_addr, udp_remote_addr_len
        );
    } else {
        n_sent = send(tcp_sock, payload, size, 0);
    }
    if (n_sent < 0) {
        checkForConnectionReset();
        char msg[20 * 2];
        ellipses(msg, sizeof(msg), snprintf(
            msg, sizeof(msg), "commSend() errno %d", errno
        ));
        ESP_LOGE(PROJECT_TAG, "%s", msg);
        abort();
    }
}
inline void commSendUDP(uint8_t const * payload, size_t size) {
    commSend(true,  payload, size);
}
inline void commSendTCP(uint8_t const * payload, size_t size) {
    commSend(false, payload, size);
}
inline void commSendUDPChars(char const * payload, size_t size) {
    commSendUDP((uint8_t*) payload, size);
}
inline void commSendTCPChars(char const * payload, size_t size) {
    commSendTCP((uint8_t*) payload, size);
}

void initComm(
    CommCallbackRecv_t _onRecv
) {
    onRecv = _onRecv;

    ESP_LOGI(PROJECT_TAG, "NVS...");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_LOGI(PROJECT_TAG, "NVS ok");

    wifi_init_sta();
    
    initUDP();
    initTCP();
    ready_to_send = true;

    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) udpReceiver, "udpRcvr", 
        1024 * 4, NULL, PRIORITY_UDP_RECEIVER, NULL
    ));
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) tcpReceiver, "tcpRcvr", 
        1024 * 4, NULL, PRIORITY_TCP_RECEIVER, NULL
    ));
}
