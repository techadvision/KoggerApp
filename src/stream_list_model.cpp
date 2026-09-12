#include "stream_list_model.h"
#include <QDebug>


StreamListModel::StreamListModel(QObject* parent)
    : QAbstractListModel(parent) {
    connect(this, &StreamListModel::appendEvent, this, &StreamListModel::doAppend);
}


QVariant StreamListModel::data(const QModelIndex &index, int role) const{
    // Check that role is valid.
    //qDebug() << "StreamListModel check 1";
    if (role < 0 || role >= _vectors.size()) {
        return QVariant("No data");
    }
    //qDebug() << "StreamListModel check 2";
    const int indexRow = index.row();
    //qDebug() << "StreamListModel check 3";
    QVector<QVariant> vectorRole = _vectors[role];
    //qDebug() << "StreamListModel check 4";
    if (indexRow < 0 || vectorRole.size() <= indexRow) {
        return {"No data"};
    }
    return _vectors[role][indexRow];
}

QHash<int, QByteArray> StreamListModel::roleNames() const {
    return _roleNames;
}

void StreamListModel::doAppend(int id, uint32_t size, uint32_t doneSize, const QString& time, int recordState, int uploadState) {

    if(!_index.contains(id)) {
        beginInsertRows(QModelIndex(), 0, 0);

        _vectors[StreamListModel::Visibility].prepend(true);
        _vectors[StreamListModel::ID].prepend(id);
        _vectors[StreamListModel::Size].prepend(size);
        _vectors[StreamListModel::DoneSize].prepend(doneSize);
        _vectors[StreamListModel::Time].prepend(time);
        _vectors[StreamListModel::RecordState].prepend(recordState);
        _vectors[StreamListModel::UploadingState].prepend(uploadState);

        for (auto it = _index.begin(); it != _index.end(); ++it)
            ++it.value();
        _index[id] = 0;
        _size++;
        endInsertRows();
    } else {
        int line = _index[id];
        _vectors[StreamListModel::Visibility][line] = (true);
        _vectors[StreamListModel::ID][line] = (id);
        _vectors[StreamListModel::Size][line] = (size);
        _vectors[StreamListModel::DoneSize][line] = (doneSize);
        _vectors[StreamListModel::Time][line] = (time);
        _vectors[StreamListModel::RecordState][line] = (recordState);
        _vectors[StreamListModel::UploadingState][line] = (uploadState);
        Q_EMIT dataChanged(index(line, 0), index(line, 0));
    }
}
