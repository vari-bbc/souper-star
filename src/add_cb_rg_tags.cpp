#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

struct Options {
    std::string mode = "regex";
    std::string pattern = "([ACGTN]+(?:-[0-9]+)?)$";
    std::string index_suffix;
    int colon_field = 5;
    int tail_length = 0;
};

static std::vector<std::string> split(const std::string& s, char delim) {
    std::vector<std::string> fields;
    std::string item;
    std::stringstream ss(s);
    while (std::getline(ss, item, delim)) {
        fields.push_back(item);
    }
    return fields;
}

static bool starts_with(const std::string& value, const std::string& prefix) {
    return value.rfind(prefix, 0) == 0;
}

static std::string extract_barcode(const std::string& qname, const Options& opt) {
    std::string barcode;

    if (opt.mode == "regex") {
        std::regex re(opt.pattern);
        std::smatch match;
        if (std::regex_search(qname, match, re)) {
            barcode = match.size() > 1 ? match[1].str() : match[0].str();
        }
    } else if (opt.mode == "colon") {
        auto fields = split(qname, ':');
        if (opt.colon_field < 1 || opt.colon_field > static_cast<int>(fields.size())) {
            throw std::runtime_error("colon-field is outside the read-name field count for: " + qname);
        }
        barcode = fields[opt.colon_field - 1];
    } else if (opt.mode == "underscore") {
        auto pos = qname.find('_');
        barcode = pos == std::string::npos ? qname : qname.substr(0, pos);
    } else if (opt.mode == "auto") {
        auto colon_fields = split(qname, ':');
        if (colon_fields.size() > 1) {
            barcode = colon_fields.back();
        } else {
            auto pos = qname.find('_');
            barcode = pos == std::string::npos ? qname : qname.substr(0, pos);
        }
    } else if (opt.mode == "tail") {
        if (opt.tail_length <= 0) {
            throw std::runtime_error("tail-length must be > 0 in tail mode");
        }
        if (static_cast<size_t>(opt.tail_length) > qname.size()) {
            throw std::runtime_error("tail-length is longer than read name: " + qname);
        }
        barcode = qname.substr(qname.size() - opt.tail_length);
    } else {
        throw std::runtime_error("Unsupported mode: " + opt.mode);
    }

    if (barcode.empty()) {
        throw std::runtime_error("Could not extract barcode from read name: " + qname);
    }
    if (!opt.index_suffix.empty()) {
        barcode += "-" + opt.index_suffix;
    }
    return barcode;
}

static void usage(const char* argv0) {
    std::cerr
        << "Usage: " << argv0 << " [options] < input.sam > output.sam\n"
        << "Options:\n"
        << "  --mode STR         Barcode extraction mode: regex, colon, underscore, auto, tail [regex]\n"
        << "  --regex STR        Regex used in regex mode; first capture group is barcode\n"
        << "  --colon-field INT  1-based colon-delimited field used in colon mode [5]\n"
        << "  --tail-length INT  Number of characters to take from the end in tail mode [0]\n"
        << "  --index STR        Optional suffix appended to barcode as -STR\n";
}

static Options parse_args(int argc, char** argv) {
    Options opt;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        auto need_value = [&](const std::string& name) -> std::string {
            if (i + 1 >= argc) {
                throw std::runtime_error("Missing value for " + name);
            }
            return argv[++i];
        };

        if (arg == "--mode") {
            opt.mode = need_value(arg);
        } else if (arg == "--regex") {
            opt.pattern = need_value(arg);
        } else if (arg == "--colon-field") {
            opt.colon_field = std::stoi(need_value(arg));
        } else if (arg == "--tail-length") {
            opt.tail_length = std::stoi(need_value(arg));
        } else if (arg == "--index") {
            opt.index_suffix = need_value(arg);
        } else if (arg == "-h" || arg == "--help") {
            usage(argv[0]);
            std::exit(0);
        } else {
            throw std::runtime_error("Unknown option: " + arg);
        }
    }
    return opt;
}

int main(int argc, char** argv) {
    try {
        const Options opt = parse_args(argc, argv);
        std::string line;

        while (std::getline(std::cin, line)) {
            if (starts_with(line, "@")) {
                std::cout << line << '\n';
                continue;
            }

            auto fields = split(line, '\t');
            if (fields.size() < 11) {
                std::cerr << "Skipping malformed SAM record: " << line << '\n';
                continue;
            }

            const std::string barcode = extract_barcode(fields[0], opt);
            std::vector<std::string> out_fields(fields.begin(), fields.begin() + 11);
            for (size_t i = 11; i < fields.size(); ++i) {
                if (!starts_with(fields[i], "CB:Z:") &&
                    !starts_with(fields[i], "CR:Z:") &&
                    !starts_with(fields[i], "RG:Z:")) {
                    out_fields.push_back(fields[i]);
                }
            }
            out_fields.push_back("CB:Z:" + barcode);
            out_fields.push_back("CR:Z:" + barcode);

            for (size_t i = 0; i < out_fields.size(); ++i) {
                if (i) {
                    std::cout << '\t';
                }
                std::cout << out_fields[i];
            }
            std::cout << '\n';
        }
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "add_cb_rg_tags error: " << e.what() << '\n';
        return 1;
    }
}
