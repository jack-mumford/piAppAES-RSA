// Raspberry Pi FPGA Sender - Reads encrypted.txt and sends to FPGA
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

std::vector<unsigned char> hex_to_bytes(const std::string& hex) {
    std::vector<unsigned char> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        unsigned char byte = std::stoi(hex.substr(i, 2), nullptr, 16);
        bytes.push_back(byte);
    }
    return bytes;
}

int main(int argc, char* argv[]) {
    std::string file = "encrypted.txt";
    std::string port = "/dev/ttyUSB0";
    bool test = false;
    
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--file" && i+1 < argc) file = argv[++i];
        if (std::string(argv[i]) == "--port" && i+1 < argc) port = argv[++i];
        if (std::string(argv[i]) == "--test") test = true;
    }
    
    // Read encrypted file
    std::ifstream in(file);
    if (!in) {
        std::cerr << "ERROR: Cannot open " << file << std::endl;
        return 1;
    }
    std::string hex_data;
    std::getline(in, hex_data);
    in.close();
    
    std::cout << "Read " << hex_data.length()/2 << " bytes from " << file << std::endl;
    
    if (test) {
        std::cout << "TEST MODE: Would send to FPGA" << std::endl;
        return 0;
    }
    
    // Open serial port
    int fd = open(port.c_str(), O_RDWR | O_NOCTTY);
    if (fd < 0) {
        std::cerr << "ERROR: Cannot open serial port " << port << std::endl;
        return 1;
    }
    
    // Configure serial: 115200 baud, 8N1
    struct termios tty;
    tcgetattr(fd, &tty);
    cfsetospeed(&tty, B115200);
    cfsetispeed(&tty, B115200);
    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;
    tty.c_cflag |= (CLOCAL | CREAD);
    tty.c_cflag &= ~(PARENB | PARODD | CSTOPB | CRTSCTS);
    tty.c_iflag &= ~(IXON | IXOFF | IXANY | IGNBRK);
    tty.c_lflag = 0;
    tty.c_oflag = 0;
    tcsetattr(fd, TCSANOW, &tty);
    
    // Send data
    auto bytes = hex_to_bytes(hex_data);
    ssize_t written = write(fd, bytes.data(), bytes.size());
    tcdrain(fd);
    close(fd);
    
    if (written == (ssize_t)bytes.size()) {
        std::cout << "✓ Sent " << written << " bytes to FPGA" << std::endl;
        return 0;
    } else {
        std::cerr << "ERROR: Write failed" << std::endl;
        return 1;
    }
}