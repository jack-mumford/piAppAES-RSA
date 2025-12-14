// Raspberry Pi FPGA Sender - Reads encrypted.txt and sends to FPGA
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

using namespace std;

vector<unsigned char> hex_to_bytes(const string& hex) {
    vector<unsigned char> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        unsigned char byte = stoi(hex.substr(i, 2), nullptr, 16);
        bytes.push_back(byte);
    }
    return bytes;
}

int main(int argc, char* argv[]) {
    string file = "encrypted.txt";
    string port = "/dev/ttyUSB0";
    bool test = false;
    
    for (int i = 1; i < argc; i++) {
        if (string(argv[i]) == "--file" && i+1 < argc) file = argv[++i];
        if (string(argv[i]) == "--port" && i+1 < argc) port = argv[++i];
        if (string(argv[i]) == "--test") test = true;
    }
    
    // Read encrypted file
    ifstream in(file);
    if (!in) {
        cerr << "ERROR: Cannot open " << file << endl;
        return 1;
    }
    string hex_data;
    getline(in, hex_data);
    in.close();
    
    cout << "Read " << hex_data.length()/2 << " bytes from " << file << endl;
    
    if (test) {
        cout << "TEST MODE: Would send to FPGA" << endl;
        return 0;
    }
    
    // Open serial port
    int fd = open(port.c_str(), O_RDWR | O_NOCTTY);
    if (fd < 0) {
        cerr << "ERROR: Cannot open serial port " << port << endl;
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
        cout << "✓ Sent " << written << " bytes to FPGA" << endl;
        return 0;
    } else {
        cerr << "ERROR: Write failed" << endl;
        return 1;
    }
}