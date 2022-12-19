Category = {
    web = "Web Exploitation",
    crypto = "Cryptography",
    rev = "Reverse Engineering",
    forensics = "Forensics",
    general = "General Skills",
    binary_expl = "Binary Exploitation",
}

Challenges = {
    {
        category = Category.web,
        challenges = {
            { "Web Challenge 1",
                "Description of the web 1 chal heh<br><br>Link: <a href=\"/static/challenge1.txt\">challenge.txt</a>",
                100, "flag{web_is_not_that_hard}" },
            { "Web Challenge 2",
                "Description of the web 2 chal heh<br><br>Link: <a href=\"https://eg-zine.cf/issues/1.html\" target=_blank>https://eg-zine.cf/issues/1.html</a>",
                150,
                "flag{web_is_not_that_hard}" },
        }
    },
    {
        category = Category.crypto,
        challenges = {
            { "Crypto Challenge 1",
                "Description of the crypto 1 chal heh<br><br>Link: <a href=\"https://eg-zine.cf/issues/2.html\" target=_blank>https://eg-zine.cf/issues/2.html</a>",
                250, "flag{crypto_is_not_that_hard}" },
        }
    },
    {
        category = Category.rev,
        challenges = {
        }
    },
    {
        category = Category.forensics,
        challenges = {
        }
    },
    {
        category = Category.general,
        challenges = {
        }
    },
    {
        category = Category.binary_expl,
        challenges = {
        }
    },
}

return Challenges
