# 📜 Contrat Obligatoire d'un Module Activable — Dioufy-TS

Tout module compilé intégré dans l'application doit respecter ce contrat d'architecture avant d'être exposé via Feature Flag.

---

## 📋 1. Fiche de Spécification du Module

```markdown
### [Nom du Module] — Ex: Module Clôture de Caisse (`module_cash_closure`)

1. **Propriétaire & Domaine Métier** :
   - Équipe ou expert référent (ex: Contrôle Financier & Exploitation GIE).
   - Délimitation DDD du contexte métier.

2. **Objectif Utilisateur & Valeur** :
   - Quel problème concret ce module résout-il pour le chauffeur, le coxeur ou le passager ?

3. **Graphe de Dépendances (Préréquis)** :
   - Quels modules ou drapeaux doivent obligatoirement être actifs au préalable ?
   - Ex: `FLAG_AUTO_MOBILE_MONEY_PAYOUT` exige `FLAG_PAYMENT_DIGITAL_WAVE`.

4. **Matrice des Permissions Requises (RBAC)** :
   - Liste des permissions nécessaires pour interagir avec le module (ex: `cash.close_session`).
   - Rôles autorisés et cloisonnement multi-tenancy (`organization_id`).

5. **Données & Intégrité** :
   - Tables et colonnes PostgreSQL associées.
   - Règles d'audit trail et d'immutabilité des transactions.

6. **Règle « Désactiver ≠ Supprimer »** :
   - Que se passe-t-il exactement lorsque le Super Admin passe le flag à `disabled` ou `maintenance` ?
   - Les données historiques doivent rester 100% accessibles en lecture.
   - Les nouvelles écritures doivent être bloquées avec un message explicatif clair.

7. **Résilience Réseau & Zéro Écran Blanc** :
   - Comportement en cas de perte de réseau (3G/4G instable).
   - Écran ou widget de repli (*Fallback UI*) obligatoire avec bouton retour.

8. **Critères de Sortie & Validation par les Tests** :
   - Fichiers de tests associés dans `test/`.
   - Tests de calcul financier, de permissions et de régression d'interface.
```

---

## 🛡️ 2. Interface Dart Standard (`AppModule`)

Chaque module présent dans `lib/modules/` implémente ce contrat d'initialisation :

```dart
abstract interface class AppModule {
  String get id;
  String get name;
  String get flagKey;
  
  Future<void> initialize();
  bool isAccessible();
  Widget buildEntryWidget(BuildContext context);
}
```

---

## ✅ 3. Checklist de Validation Pré-Déploiement

Avant d'activer un module en production :
- [ ] Le module est compilé dans le binaire (aucun code-push distant).
- [ ] Ses dépendances dans `FeatureFlagState` sont résolues.
- [ ] Ses permissions sont inscrites dans `AppPermission.allPermissions`.
- [ ] Les montants monétaires sont rigoureusement en **FCFA** (badge rond `XOF`).
- [ ] Les calculs financiers critiques s'exécutent sur le serveur.
- [ ] Chaque écran comporte son bouton retour de navigation.
- [ ] La suite de tests unitaires passe à 100% sans exception.
