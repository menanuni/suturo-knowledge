#!/usr/bin/env python

import pickle
import itertools
import numpy as np
import matplotlib.pyplot as plt
import rospkg

from sklearn import svm
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn import cross_validation
from sklearn import metrics

def plot_confusion_matrix(cm, classes, normalize=False, title='Confusion matrix', cmap=plt.cm.Blues):
  plt.imshow(cm, interpolation='nearest', cmap=cmap)
  plt.title(title)
  plt.colorbar()
  tick_marks = np.arange(len(classes))
  plt.xticks(tick_marks, classes, rotation=45)
  plt.yticks(tick_marks, classes)

  if normalize:
    cm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]

  thresh = cm.max() / 2.
  for i, j in itertools.product(range(cm.shape[0]), range(cm.shape[1])):
    plt.text(j, i, '{0:.2f}'.format(cm[i, j]), horizontalalignment="center", color="white" if cm[i, j] > thresh else "black")

  plt.tight_layout()
  plt.ylabel('True label')
  plt.xlabel('Predicted label')

if __name__ == '__main__':
  # Load training data from disk
  rospack = rospkg.RosPack()
  packagePath = rospack.get_path('svm_classifier')
  fullPath = packagePath + '/data/training_set.sav'
  training_set = pickle.load(open(fullPath, 'rb'))

  # Format the features and labels for use with scikit learn
  feature_list = []
  label_list = []

  for item in training_set:
    if np.isnan(item[0]).sum() < 1: # if there are no NaN s in the item[0] array
        feature_list.append(item[0]) # add to the feature list
        label_list.append(item[1])

  print('Features in Training Set: {}'.format(len(training_set)))
  print('Invalid Features in Training set: {}'.format(len(training_set)-len(feature_list)))

  X = np.array(feature_list)
  # Fit a per-column scaler
  X_scaler = StandardScaler().fit(X)
  # Apply the scaler to X
  X_train = X_scaler.transform(X)
  y_train = np.array(label_list)

  # Convert label strings to numerical encoding
  encoder = LabelEncoder()
  y_train = encoder.fit_transform(y_train)

  # Create classifier
  clf = svm.SVC(kernel='linear')

  # Set up 5-fold cross-validation
  kf = cross_validation.KFold(len(X_train), n_folds=5, shuffle=True, random_state=1)

  # Perform cross-validation
  scores = cross_validation.cross_val_score(cv=kf, estimator=clf, X=X_train, y=y_train, scoring='accuracy')
  print('Scores: ' + str(scores))
  print('Accuracy: %0.2f (+/- %0.2f)' % (scores.mean(), 2*scores.std()))

  # Gather predictions
  predictions = cross_validation.cross_val_predict(cv=kf, estimator=clf, X=X_train, y=y_train)

  accuracy_score = metrics.accuracy_score(y_train, predictions)
  print('accuacy score: '+str(accuracy_score))

  confusion_matrix = metrics.confusion_matrix(y_train, predictions)

  class_names = encoder.classes_.tolist()

  #Train the classifier
  clf.fit(X=X_train, y=y_train)

  model = {'classifier': clf, 'classes': encoder.classes_, 'scaler': X_scaler}

  # Save classifier to disk
  packagePath = rospack.get_path('svm_classifier')
  fullPath = packagePath + '/data/svm_model.sav'
  pickle.dump(model, open(fullPath, 'wb'))

  # Plot non-normalized confusion matrix
  plt.figure()
  plot_confusion_matrix(confusion_matrix, classes=encoder.classes_, title='Confusion matrix, without normalization')

  # Plot normalized confusion matrix
  plt.figure()
  plot_confusion_matrix(confusion_matrix, classes=encoder.classes_, normalize=True, title='Normalized confusion matrix')

  plt.show()