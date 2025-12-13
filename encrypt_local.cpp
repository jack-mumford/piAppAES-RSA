// Simple encryption tool - Encrypts secret.txt to encrypted.txt
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <openssl/sha.h>

std::string to_hex(const unsigned char* data, size_t len) {
    std::stringstream ss;
    ss << std::hex << std::setfill('0');
    for (size_t i = 0; i < len; ++i) {
        ss << std::setw(2) << (int)data[i];
    }
    return ss.str();
}

int main(int argc, char* argv[]) {
    std::string input = "piApp/secret.txt";
    std::string output = "piApp/encrypted.txt";
    
    if (argc > 1 && std::string(argv[1]) == "--help") {
        std::cout << "Usage: " << argv[0] << " [--input FILE] [--output FILE]\n";
        return 0;
    }
    
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--input" && i+1 < argc) input = argv[++i];
        if (std::string(argv[i]) == "--output" && i+1 < argc) output = argv[++i];
    }
    
    // Read secret
    std::ifstream in(input);
    if (!in) {
        std::cerr << "ERROR: Cannot open " << input << std::endl;
        return 1;
    }
    std::string secret((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    in.close();
    
    std::cout << "Encrypting " << secret.length() << " bytes from " << input << std::endl;
    
    // Simple encryption: XOR with SHA256 hash
    unsigned char key[SHA256_DIGEST_LENGTH];
    SHA256((unsigned char*)"FPGA_ENCRYPTION_KEY", 19, key);
    
    std::string encrypted;
    for (size_t i = 0; i < secret.length(); i++) {
        encrypted += secret[i] ^ key[i % SHA256_DIGEST_LENGTH];
    }
    
    // Write encrypted hex
    std::ofstream out(output);
    if (!out) {
        std::cerr << "ERROR: Cannot write " << output << std::endl;
        return 1;
    }
    out << to_hex((unsigned char*)encrypted.c_str(), encrypted.length()) << std::endl;
    out.close();
    
    std::cout << "✓ Encrypted to " << output << std::endl;
    return 0;
}
