#pragma once

static bool constexpr safe_list = true;

template <class Type, unsigned Size> class list final {
  public:
    Type data[Size]{};
    size_t len{};

    class position {
        friend class list;
        size_t index{};
        position(size_t ix) : index{ix} {}
    };

    auto length() const -> size_t { return len; }

    auto is_at_end(position pos) const -> bool { return pos.index == len; }

    auto add(Type elem) -> bool {
        if constexpr (safe_list) {
            if (len == Size - 1) {
                return false;
            }
        }
        data[len] = elem;
        ++len;
        return true;
    }

    auto remove(Type elem) -> bool {
        for (size_t i = 0; i < len; ++i) {
            if (data[i] != elem) {
                continue;
            }
            --len;
            for (size_t j = i; j < len; ++j) {
                data[j] = data[j + 1];
            }
            return true;
        }
        return false;
    }

    auto remove_at(position const pos) -> bool {
        if constexpr (safe_list) {
            if (pos.index >= len) {
                return false;
            }
        }
        --len;
        for (size_t i = pos.index; i < len; ++i) {
            data[i] = data[i + 1];
        }
        return true;
    }

    auto at(position const pos) const -> Type {
        if constexpr (safe_list) {
            if (pos.index >= len) {
                return {};
            }
        }
        return data[pos.index];
    }

    auto for_each(callable_returns_void<Type> auto&& f) const -> void {
        for (size_t i = 0; i < len; ++i) {
            f(data[i]);
        }
    }

    auto for_each_until_false(callable_returns_bool<Type> auto&& f) const
        -> position {
        size_t i = 0;
        for (; i < len; ++i) {
            if (!f(data[i])) {
                return {i};
            }
        }
        return {i};
    }
};
