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
    
    // Read secret
    ifstream in(input);
    if (!in) {
        cerr << "ERROR: Cannot open " << input << endl;
        return 1;
    }
    string secret((istreambuf_iterator<char>(in)), istreambuf_iterator<char>());
    in.close();
    
    cout << "Encrypting " << secret.length() << " bytes from " << input << endl;
    
    // Simple encryption: XOR with SHA256 hash
    unsigned char key[SHA256_DIGEST_LENGTH];
    SHA256((unsigned char*)"FPGA_ENCRYPTION_KEY", 19, key);
    
    string encrypted;
    for (size_t i = 0; i < secret.length(); i++) {
        encrypted += secret[i] ^ key[i % SHA256_DIGEST_LENGTH];
    }
    
    // Write encrypted hex
    ofstream out(output);
    if (!out) {
        cerr << "ERROR: Cannot write " << output << endl;
        return 1;
    }
    out << to_hex((unsigned char*)encrypted.c_str(), encrypted.length()) << endl;
    out.close();
    
    cout << "✓ Encrypted to " << output << endl;
    return 0;
}
