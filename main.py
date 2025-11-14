from enums import Role


def login():
    print("Select role: [1] Manufacturer\t[2] Supplier\t[3] General (viewer)")
    role = input()
    if role == Role.Manufacturer.value:
        pass
    elif role == Role.Supplier.value:
        pass
    else:
        pass



if __name__ == "main":
    pass