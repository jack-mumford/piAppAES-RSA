// Simple encryption tool - Encrypts secret.txt to encrypted.txt
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <openssl/sha.h>

using namespace std;

string to_hex(const unsigned char* data, size_t len) {
    stringstream ss;
    ss << hex << setfill('0');
    for (size_t i = 0; i < len; ++i) {
        ss << setw(2) << (int)data[i];
    }
    return ss.str();
}

vector<unsigned char> hex_to_bytes(const string& hex) {
    vector<unsigned char> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        if (i + 1 < hex.length()) {
            unsigned char byte = stoi(hex.substr(i, 2), nullptr, 16);
            bytes.push_back(byte);
        }
    }
    return bytes;
}

int main(int argc, char* argv[]) {
    string input = "piApp/secret.txt";
    string output = "piApp/encrypted.txt";
    
    if (argc > 1 && string(argv[1]) == "--help") {
        cout << "Usage: " << argv[0] << " [--input FILE] [--output FILE]\n";
        return 0;
    }
    
    for (int i = 1; i < argc; i++) {
        if (string(argv[i]) == "--input" && i+1 < argc) input = argv[++i];
        if (string(argv[i]) == "--output" && i+1 < argc) output = argv[++i];
    }
    
    // Read secret (hex string)
    ifstream in(input);
    if (!in) {
        cerr << "ERROR: Cannot open " << input << endl;
        return 1;
    }
    string hex_input;
    getline(in, hex_input);
    in.close();
    
    // Convert hex string to bytes
    auto secret_bytes = hex_to_bytes(hex_input);
    cout << "Encrypting " << secret_bytes.size() << " bytes from " << input << endl;
    
    // Fixed key for specific encryption result
    unsigned char key[16] = {
        0xA3, 0x5E, 0x65, 0x52, 0x3F, 0x4D, 0xA0, 0xF0,
        0xDB, 0x8A, 0x4A, 0xA3, 0x71, 0x78, 0x76, 0xDA
    };
    
    vector<unsigned char> encrypted;
    for (size_t i = 0; i < secret_bytes.size(); i++) {
        encrypted.push_back(secret_bytes[i] ^ key[i % 16]);
    }
    
    // Write encrypted hex
    ofstream out(output);
    if (!out) {
        cerr << "ERROR: Cannot write " << output << endl;
        return 1;
    }
    out << to_hex(encrypted.data(), encrypted.size()) << endl;
    out.close();
    
    cout << "✓ Encrypted to " << output << endl;
    return 0;
}
