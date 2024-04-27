# Premier pas avec git

### **Votre identité**

La première chose à faire après l’installation de Git est de renseigner votre nom et votre adresse de courriel. C’est une information importante car toutes les validations dans Git utilisent cette information et elle est indélébile dans toutes les validations que vous pourrez réaliser :

```bash
git config --global user.name "John Doe"
git config --global user.email johndoe@example.com
```

Encore une fois, cette étape n’est nécessaire qu’une fois si vous passez l’option `--global`, parce que Git utilisera toujours cette information pour tout ce que votre utilisateur fera sur ce système. Si vous souhaitez surcharger ces valeurs avec un nom ou une adresse de courriel différents pour un projet spécifique, vous pouvez lancer ces commandes sans option `--global` lorsque vous êtes dans ce projet.

De nombreux outils graphiques vous aideront à le faire la première fois que vous les lancerez.